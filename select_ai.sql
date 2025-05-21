---------------------------------------------------------------
-- Select AI
CREATE OR REPLACE DIRECTORY ONNX_DIR AS 'onnx_model';

-- Import LLM model from object storage into the directory
BEGIN
  DBMS_CLOUD.GET_OBJECT(                           
        credential_name => NULL,
        directory_name  => 'ONNX_DIR',
        object_uri      => 'https://objectstorage.eu-paris-1.oraclecloud.com/p/.../b/devweek2025/o/all_MiniLM_L12_v2.onnx');
END;
/

-- Load the LLM model from the directory into the database
BEGIN
  DBMS_VECTOR.LOAD_ONNX_MODEL(
        directory  => 'ONNX_DIR',
        file_name  => 'all_MiniLM_L12_v2.onnx',
        model_name => 'MY_ONNX_MODEL');
END;
/

-- Check the model is loaded
SELECT model_name, algorithm, mining_function
FROM user_mining_models
WHERE  model_name='MY_ONNX_MODEL';

-- Create a SELECT AI profile
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
     profile_name => 'EMBEDDING_PROFILE',
     attributes   => '{"provider" : "database",
                       "embedding_model": "MY_ONNX_MODEL"}'
  );
END;
/

EXEC DBMS_CLOUD_AI.SET_PROFILE('EMBEDDING_PROFILE');

-- OCI GEN AI model
-- Create the object store credential
BEGIN
      DBMS_CLOUD.CREATE_CREDENTIAL(
        credential_name => 'OCI_CRED',
        username => '',
        password => ''
      );
END;
/
--Create GenAI credentials
declare
  pk varchar2(4000) := '-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
OCI_API_KEY';
BEGIN                                                         
  DBMS_CLOUD.DROP_CREDENTIAL( credential_name => 'GENAI_CRED' );  

  DBMS_CLOUD.CREATE_CREDENTIAL(                                              
    credential_name => 'GENAI_CRED',                                         
    user_ocid       => 'ocid1.user.',
    tenancy_ocid    => 'ocid1.tenancy.',
    private_key     => pk,
    fingerprint     => '...'
  );                                                                         
END;                                                                        
/
--Create OCI AI profile
BEGIN
  DBMS_CLOUD_AI.DROP_PROFILE(profile_name => 'OCI_GENAI');
  DBMS_CLOUD_AI.CREATE_PROFILE(
     profile_name => 'OCI_GENAI',
     attributes   => '{"provider": "oci",
                       "model": "meta.llama-3.3-70b-instruct",
                       "max_tokens":512,
                       "credential_name": "GENAI_CRED",
                       "vector_index_name": "MY_INDEX",
                       "embedding_model": "database: MY_ONNX_MODEL",
                       "conversation": true}'
  );
END;
/

------------------------------------------------
EXEC DBMS_CLOUD_AI.SET_PROFILE('OCI_GENAI');

-- create a vector index with the vector store name, object store location
-- and object store credential
BEGIN
       begin DBMS_CLOUD_AI.DROP_VECTOR_INDEX(
         index_name  => 'MY_INDEX' );
       exception when others then null;
       end;  

       DBMS_CLOUD_AI.CREATE_VECTOR_INDEX(
         index_name  => 'MY_INDEX',
         attributes  => '{"vector_db_provider": "oracle",
                          "location": "https://....objectstorage.eu-paris-1.oci.customer-oci.com/p/.../b/devweek2025/o/",
                          "object_storage_credential_name": "OCI_CRED",
                          "profile_name": "OCI_GENAI",
                          "vector_dimension": 384,
                          "vector_distance_metric": "cosine",
                          "chunk_overlap":128,
                          "chunk_size":1024,
                          "match_limit":4
      }',
      status => 'Enabled');
END;
/
-- end installation

-- Demo starts!
EXEC DBMS_CLOUD_AI.SET_PROFILE('OCI_GENAI');

select ai narrate what is a JSON schema;
select ai chat what are the use cases for json schema;
select ai chat summarize the use cases for json schema and give me only the 3 most important;

select ai narrate what is a JSON Relational Duality view;

select dbms_cloud_ai.generate(
    prompt => 'Is it possible to migrate from MongoDB to Oracle database?',
    profile_name => 'OCI_GENAI',
    action => 'narrate'
) as response;

select ai narrate what is the Oracle Database API for MongoDB;

select ai narrate what is the OSON format for the Oracle database;

select ai narrate what is the usage of the column ETAG for a json collection table;