#!/bin/bash

# Define constants
export HOST="https://localhost:9200"
export USER="admin"
export PASSWORD="Secretpassword1!"

# Function to wait for task completion
wait_for_task_completion() {
    local task_id=$1
    local task_status
    while true; do
        task_status=$(curl -s -XGET --insecure -u $USER:$PASSWORD "$HOST/_plugins/_ml/tasks/$task_id" | jq -r '.state')
        if [[ $task_status == "COMPLETED" ]]; then
            break
        elif [[ $task_status == "FAILED" ]]; then
            echo "Task $task_id failed"
            exit 1
        fi
        echo "Waiting for task $task_id to complete..."
        sleep 5
    done
}

# Cluster settings
curl -XPUT --insecure -u $USER:$PASSWORD "$HOST/_cluster/settings" -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "plugins": {
      "ml_commons": {
        "allow_registering_model_via_url": "true",
        "only_run_on_ml_node": "false",
        "model_access_control_enabled": "true",
        "native_memory_threshold": "99"
      }
    }
  }
}'

# Create model group
export MODEL_GROUP_ID=$(curl -s -XPOST --insecure -u $USER:$PASSWORD "$HOST/_plugins/_ml/model_groups/_register" -H 'Content-Type: application/json' -d'
{
  "name": "NLP_model_group",
  "description": "A model group for NLP models",
  "access_mode": "public"
}' | jq -r '.model_group_id')

echo "Model Group ID: $MODEL_GROUP_ID"

# Register model
export TASK_ID=$(curl -s -XPOST --insecure -u $USER:$PASSWORD "$HOST/_plugins/_ml/models/_register" -H 'Content-Type: application/json' -d'
{
    "name": "sentence-transformers/msmarco-distilbert-base-tas-b",
    "version": "1.0.2",
    "description": "This is a port of the DistilBert TAS-B Model to sentence-transformers model: It maps sentences & paragraphs to a 768 dimensional dense vector space and is optimized for the task of semantic search. This model version automatically truncates to a maximum of 512 tokens.",
    "model_format": "TORCH_SCRIPT",
    "model_task_type": "TEXT_EMBEDDING",
    "model_config": {
        "model_type": "distilbert",
        "embedding_dimension": 768,
        "framework_type": "sentence_transformers",
        "pooling_mode": "CLS",
        "normalize_result": false,
        "all_config": "{\"_name_or_path\": \"/root/.cache/torch/sentence_transformers/sentence-transformers_msmarco-distilbert-base-tas-b/\", \"activation\": \"gelu\", \"architectures\": [\"DistilBertModel\"], \"attention_dropout\": 0.1, \"dim\": 768, \"dropout\": 0.1, \"hidden_dim\": 3072, \"initializer_range\": 0.02, \"max_position_embeddings\": 512, \"model_type\": \"distilbert\", \"n_heads\": 12, \"n_layers\": 6, \"pad_token_id\": 0, \"qa_dropout\": 0.1, \"seq_classif_dropout\": 0.2, \"sinusoidal_pos_embds\": false, \"tie_weights_\": true, \"torch_dtype\": \"float32\", \"transformers_version\": \"4.33.2\", \"vocab_size\": 30522}"
    },
    "model_content_size_in_bytes": 266363799,
    "model_content_hash_value": "54ee88869b39f0b7d7cede249409286333d152a49146259d271041fef5d39f03",
    "created_time": 1676073973126,
    "url": "https://artifacts.opensearch.org/models/ml-models/huggingface/sentence-transformers/msmarco-distilbert-base-tas-b/1.0.2/torch_script/sentence-transformers_msmarco-distilbert-base-tas-b-1.0.2-torch_script.zip"
}' | jq -r '.task_id')

if [[ -z $TASK_ID ]]; then
    echo "Failed to get task ID"
    exit 1
fi

echo "Task ID: $TASK_ID"

# Wait for task completion and get model ID
wait_for_task_completion $TASK_ID
export MODEL_ID=$(curl -s -XGET --insecure -u $USER:$PASSWORD "$HOST/_plugins/_ml/tasks/$TASK_ID" | jq -r '.model_id')

if [[ -z $MODEL_ID ]]; then
    echo "Failed to get model ID"
    exit 1
fi

echo "Model ID: $MODEL_ID"

# Deploy model
export DEPLOY_TASK_ID=$(curl -s -XPOST --insecure -u $USER:$PASSWORD "$HOST/_plugins/_ml/models/$MODEL_ID/_deploy" | jq -r '.task_id')

if [[ -z $DEPLOY_TASK_ID ]]; then
    echo "Failed to get deploy task ID"
    exit 1
fi

echo "Deploy Task ID: $DEPLOY_TASK_ID"

# Wait for deployment task completion
wait_for_task_completion $DEPLOY_TASK_ID

# Create ingest pipeline
curl -XPUT --insecure -u $USER:$PASSWORD "$HOST/_ingest/pipeline/nlp-ingest-pipeline" -H 'Content-Type: application/json' -d'
{
  "description": "A text embedding pipeline",
  "processors": [
    {
      "text_embedding": {
        "model_id": "'$MODEL_ID'",
        "field_map": {
          "scriptureText": "scriptureTextEmbedding"
        }
      }
    }
  ]
}'

# Verify pipeline creation
export PIPELINE_EXISTS=$(curl -s -XGET --insecure -u $USER:$PASSWORD "$HOST/_ingest/pipeline/nlp-ingest-pipeline" | jq -r '."nlp-ingest-pipeline"')
if [[ -z $PIPELINE_EXISTS ]]; then
    echo "Pipeline creation failed"
    exit 1
fi

# Close index
curl -XPOST --insecure -u $USER:$PASSWORD "$HOST/ai_mormon_scriptures/_close"

# Check if the index is closed
export INDEX_STATUS=$(curl -s -XGET --insecure -u $USER:$PASSWORD "$HOST/ai_mormon_scriptures/_settings" | jq -r '."ai_mormon_scriptures".settings.index.verified_before_close')
if [[ $INDEX_STATUS != "true" ]]; then
    echo "Index closure failed or verification failed. Retrying..."
    sleep 5
    curl -XPOST --insecure -u $USER:$PASSWORD "$HOST/ai_mormon_scriptures/_close"
fi

# Update settings and mappings
curl -XPUT --insecure -u $USER:$PASSWORD "$HOST/ai_mormon_scriptures/_settings" -H 'Content-Type: application/json' -d'
{
  "index.knn": true,
  "default_pipeline": "nlp-ingest-pipeline"
}'

curl -XPUT --insecure -u $USER:$PASSWORD "$HOST/ai_mormon_scriptures/_mapping" -H 'Content-Type: application/json' -d'
{
  "properties": {
    "scriptureTextEmbedding": {
      "type": "knn_vector",
      "dimension": 768,
      "method": {
        "engine": "lucene",
        "space_type": "l2",
        "name": "hnsw",
        "parameters": {}
      }
    }
  }
}'

# Open index
curl -XPOST --insecure -u $USER:$PASSWORD "$HOST/ai_mormon_scriptures/_open"

# Update search pipeline
curl -XPUT --insecure -u $USER:$PASSWORD "$HOST/_search/pipeline/default_model_pipeline" -H 'Content-Type: application/json' -d'
{
  "request_processors": [
    {
      "neural_query_enricher" : {
        "default_model_id": "'$MODEL_ID'",
        "neural_field_default_id": {
           "scriptureText": "scriptureTextEmbedding"
        }
      }
    }
  ]
}'

# Set index default search pipeline
curl -XPUT --insecure -u $USER:$PASSWORD "$HOST/ai_mormon_scriptures/_settings" -H 'Content-Type: application/json' -d'
{
  "index.search.default_pipeline" : "default_model_pipeline"
}'

# Perform search with a specific pipeline
curl -XGET --insecure -u $USER:$PASSWORD "$HOST/ai_mormon_scriptures/_search" -H 'Content-Type: application/json' -d'
{
  "_source": {
    "exclude": [
      "volumeTitle",
      "scriptureTextEmbedding",
      "volumeSubtitle",
      "volumeLdsUrl",
      "verseId",
      "verseNumber",
      "chapterNumber",
      "_entity",
      "bookId",
      "volumeShortTitle",
      "bookLdsUrl",
      "bookLongTitle",
      "chapterId",
      "volumeId",
      "bookShortTitle",
      "verseShortTitle",
      "bookTitle"
    ]
  },
  "query": {
    "hybrid": {
      "queries": [
        {
          "match": {
            "scriptureText": {
              "query": "Hi world"
            }
          }
        },
        {
          "neural": {
            "scriptureTextEmbedding": {
              "query_text": "Hi world",
              "model_id": "'$MODEL_ID'",
              "k": 5
            }
          }
        }
      ]
    }
  }
}'
