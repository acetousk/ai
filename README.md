## A ai component

ai Component with: 

- entities
- data
- services
- REST API
- screens

To install run (with moqui-framework):

    $ ./gradlew getComponent -Pcomponent=ai

Example `MoquiProductionConf.xml`
```xml
<?xml version="1.0" encoding="UTF-8" ?>
<!-- No copyright or license for configuration file, details here are not considered a creative work. -->

<!-- NOTE: for default settings, examples, and comments see the MoquiDefaultConf.xml file at
    https://github.com/moqui/moqui-framework/blob/master/framework/src/main/resources/MoquiDefaultConf.xml -->
<moqui-conf xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://moqui.org/xsd/moqui-conf-3.xsd">

    <server-stats stats-skip-condition="pathInfo?.startsWith('/rpc') || pathInfo?.startsWith('/rest') || pathInfo?.startsWith('/status')"/>

    <default-property name="elasticsearch_url" value="https://127.0.0.1:9200"/>
    <default-property name="elasticsearch_user" value="admin"/>
    <default-property name="elasticsearch_password" value="Secretpassword1!"/>

    <!-- NOTE: using the environment variable is relatively secure in a container environment, but for more security set it here instead -->
    <entity-facade crypt-pass="asdf" query-stats="true">
        <!-- add datasource elements here to configure databases -->
        <datasource group-name="transactional" database-conf-name="postgres" schema-name="public" startup-add-missing="true" runtime-add-missing="false">
            <inline-jdbc><xa-properties user="moqui" password="secretpassword" serverName="localhost" portNumber="5432"
                    databaseName="moqui"/></inline-jdbc>
        </datasource>
    </entity-facade>

    <cache-list warm-on-start="false">
        <!-- Development Mode - expires artifact cache entries; don't use these for production, load testing, etc -->
        <cache name="entity.definition" expire-time-idle="30"/>
        <!-- longer timeout since this basically looks through all files to check for new or moved entity defs -->
        <cache name="entity.location" expire-time-live="300"/>
        <cache name="entity.data.feed.info" expire-time-idle="30"/>

        <cache name="service.location" expire-time-idle="10"/>
        <cache name="service.rest.api" expire-time-idle="10"/>
        <cache name="kie.component.releaseId" expire-time-idle="10"/>

        <cache name="screen.location" expire-time-idle="10"/>
        <cache name="screen.url" expire-time-idle="10"/>
        <cache name="screen.template.mode" expire-time-idle="10"/>
        <cache name="screen.template.location" expire-time-idle="10"/>
        <cache name="screen.find.path" expire-time-idle="30"/>

        <cache name="resource.xml-actions.location" expire-time-idle="5"/>
        <cache name="resource.groovy.location" expire-time-idle="5"/>

        <cache name="resource.ftl.location" expire-time-idle="5"/>
        <cache name="resource.gstring.location" expire-time-idle="5"/>
        <cache name="resource.wiki.location" expire-time-idle="5"/>
        <cache name="resource.markdown.location" expire-time-idle="5"/>
        <cache name="resource.text.location" expire-time-idle="5"/>
        <cache name="resource.reference.location" expire-time-idle="5"/>

        <cache name="l10n.message" expire-time-idle="600"/>
    </cache-list>

</moqui-conf>
```

Run the commands needed
```bash
docker run -d --name moqui-postgres -e POSTGRES_USER=moqui -e POSTGRES_PASSWORD=secretpassword -e POSTGRES_DB=moqui -p 5432:5432 postgres
docker run -d --name moqui-opensearch -p 9200:9200 -p 9600:9600 -e "discovery.type=single-node" -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=Secretpassword1!" opensearchproject/opensearch:latest
```
See logs:
```bash
docker logs moqui-postgres
docker logs moqui-opensearch
```
Stop and remove containers
```bash
docker stop moqui-postgres
docker rm moqui-postgres
docker stop moqui-opensearch
docker rm moqui-opensearch
```

## Neural Search Curl Commands
### Create model for neural search: https://opensearch.org/docs/latest/search-plugins/neural-search-tutorial/
```bash
curl -XPUT --insecure -u admin:Secretpassword1! "https://localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
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
```
```bash
curl -XPOST --insecure -u admin:Secretpassword1! "https://localhost:9200/_plugins/_ml/model_groups/_register" -H 'Content-Type: application/json' -d'
{
  "name": "NLP_model_group",
  "description": "A model group for NLP models",
  "access_mode": "public"
}'
```
Get model_group_id for example: i1_MuJABknjzbwTIbIKH
```bash
curl -XPOST --insecure -u admin:Secretpassword1! "https://localhost:9200/_plugins/_ml/models/_register" -H 'Content-Type: application/json' -d'
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
}'
```
Get task_id for example: kV_TuJABknjzbwTIZoJ7
```bash
curl -XGET --insecure -u admin:Secretpassword1! "https://localhost:9200/_plugins/_ml/tasks/lF_VuJABknjzbwTIsYLo"
```
Get model_id for example: lV_VuJABknjzbwTIsoIA
```bash
curl -XPOST --insecure -u admin:Secretpassword1! "https://localhost:9200/_plugins/_ml/models/lV_VuJABknjzbwTIsoIA/_deploy"
```
Get task_id for example: nl_ZuJABknjzbwTIEYIy
```bash
curl -XGET --insecure -u admin:Secretpassword1! "https://localhost:9200/_plugins/_ml/tasks/nl_ZuJABknjzbwTIEYIy"
```

### Use semantic search for data documents: https://opensearch.org/docs/latest/search-plugins/semantic-search/
```bash
curl -XPUT --insecure -u admin:Secretpassword1! "https://localhost:9200/_ingest/pipeline/nlp-ingest-pipeline" -H 'Content-Type: application/json' -d'
{
  "description": "A text embedding pipeline",
  "processors": [
    {
      "text_embedding": {
        "model_id": "lV_VuJABknjzbwTIsoIA",
        "field_map": {
          "scriptureText": "scriptureTextEmbedding"
        }
      }
    }
  ]
}'
```
Temporarily close the index
```bash
curl -XPOST --insecure -u admin:Secretpassword1! "https://localhost:9200/ai_mormon_scriptures/_close"
```
```bash
curl -XPUT --insecure -u admin:Secretpassword1! "https://localhost:9200/ai_mormon_scriptures/_settings" -H 'Content-Type: application/json' -d'
{
  "index.knn": true,
  "default_pipeline": "nlp-ingest-pipeline"
}'
```
```bash
curl -XPUT --insecure -u admin:Secretpassword1! "https://localhost:9200/ai_mormon_scriptures/_mapping" -H 'Content-Type: application/json' -d'
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
```
```bash
curl -XPOST --insecure -u admin:Secretpassword1! "https://localhost:9200/ai_mormon_scriptures/_open"
```
Search
```bash
curl -XGET --insecure -u admin:Secretpassword1! "https://localhost:9200/ai_mormon_scriptures/_search" -H 'Content-Type: application/json' -d'
{
  "_source": {
    "excludes": [
      "scriptureTextEmbedding"
    ]
  },
  "query": {
    "bool": {
      "filter": {
         "wildcard":  { "id": "*1" }
      },
      "should": [
        {
          "script_score": {
            "query": {
              "neural": {
                "scriptureTextEmbedding": {
                  "query_text": "Hi world",
                  "model_id": "lV_VuJABknjzbwTIsoIA",
                  "k": 100
                }
              }
            },
            "script": {
              "source": "_score * 1.5"
            }
          }
        },
        {
          "script_score": {
            "query": {
              "match": {
                "scriptureText": "Hi world"
              }
            },
            "script": {
              "source": "_score * 1.7"
            }
          }
        }
      ]
    }
  }
}'
```
```bash
curl -XPUT --insecure -u admin:Secretpassword1! "https://localhost:9200/_search/pipeline/default_model_pipeline" -H 'Content-Type: application/json' -d'
{
  "request_processors": [
    {
      "neural_query_enricher" : {
        "default_model_id": "lV_VuJABknjzbwTIsoIA",
        "neural_field_default_id": {
           "scriptureText": "lV_VuJABknjzbwTIsoIA"
        }
      }
    }
  ]
}'
```
```bash
curl -XPUT --insecure -u admin:Secretpassword1! "https://localhost:9200/ai_mormon_scriptures/_settings" -H 'Content-Type: application/json' -d'
{
  "index.search.default_pipeline" : "default_model_pipeline"
}'
```
```bash
curl -XGET --insecure -u admin:Secretpassword1! "https://localhost:9200/ai_mormon_scriptures/_search" -H 'Content-Type: application/json' -d'
{
  "query": {
    "neural": {
      "scriptureTextEmbedding": {
        "query_text": "Mormon",
        "k": 100
      }
    }
  },
  "_source": {
    "excludes": [
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
  }
}' | jq
```
```bash
curl -XGET --insecure -u admin:Secretpassword1! "https://localhost:9200/ai_mormon_scriptures/_search?search_pipeline=nlp-ingest-pipeline" -H 'Content-Type: application/json' -d'
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
              "model_id": "lV_VuJABknjzbwTIsoIA",
              "k": 5
            }
          }
        }
      ]
    }
  }
}'
```
```bash
# Perform search with a specific pipeline
curl -X GET --insecure -u "admin:Secretpassword1!" "https://127.0.0.1:9200/ai_mormon_scriptures/_search" -H 'Content-Type: application/json' -d'
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
              "model_id": "Ty3UvJABBw3NiI4neFgn",
              "k": 5
            }
          }
        }
      ]
    }
  }
}'
```