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

-- create a vector index with the vector store name, object store location and
-- object store credential
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

EXEC DBMS_CLOUD_AI.SET_PROFILE('OCI_GENAI');

select ai narrate what is a JSON schema;
select ai narrate is a JSON schema a json document;
select ai chat what are the use cases for json schema;
select ai chat summarize the use cases for json schema and give me only the 3 most important;

select ai narrate what is a JSON Relational Duality view;

select ai narrate can we create TTL index for JSON data with the Oracle database;

select dbms_cloud_ai.generate(
    prompt => 'Is it possible to migrate from MongoDB to Oracle database?',
    profile_name => 'OCI_GENAI',
    action => 'narrate'
) as response;

select ai narrate what is the Oracle Database API for MongoDB;

select ai narrate what is the OSON format in the Oracle database;


-- ####################################################################################################
-- JSON schema

-- setup
exec ords.enable_schema;


-- Client-side validation using JSON Schema
-- https://github.com/remoteoss/json-schema-form
-- drop table if exists products purge;

create table products (
  name     varchar2(100) not null primary key constraint minimal_name_length check (length(name) >= 3),
  price    number not null constraint strictly_positive_price check (price > 0),
  quantity number not null constraint non_negative_quantity check (quantity >= 0)
);

insert into products (name, price, quantity)
values ('Cake mould',     9.99, 15),
       ('Wooden spatula', 4.99, 42);
commit;

-- JSON Schema of PRODUCTS table
-- Contains check constraints!
select dbms_json_schema.describe('PRODUCTS');

-- Leverage SQL Annotations to annotate the JSON Schema
alter table products modify NAME annotations (
  ADD OR REPLACE "title" 'Product Name',
  ADD OR REPLACE "description" 
                     'Product name (max length: 100)',
  ADD OR REPLACE "minLength" '3'
);

alter table products modify PRICE annotations (
  ADD OR REPLACE "title" 'Price',
  ADD OR REPLACE "description" 
                     'Product price strictly positive',
  ADD OR REPLACE "minimum" '0.01'
);
alter table products modify QUANTITY annotations (
  ADD OR REPLACE "title" 'Quantity',
  ADD OR REPLACE "description" 
                     'Quantity of products >= 0',
  ADD OR REPLACE "minimum" '0'
);

-- View annotations
select column_name, annotation_name, annotation_value
  from user_annotations_usage
 where object_name='PRODUCTS'
   and object_type='TABLE'
order by 1, 2;

-- Annotate JSON Schema with column level annotations
create or replace function getAnnotatedJSONSchema( p_table_name in varchar2 )
return json
as
  schema clob;
  l_schema JSON_OBJECT_T;
  l_properties JSON_OBJECT_T;
  l_keys JSON_KEY_LIST;
  l_column JSON_OBJECT_T;
begin
  -- get JSON schema of table
  select json_serialize( dbms_json_schema.describe( p_table_name )
                         returning clob ) into schema;

  l_schema := JSON_OBJECT_T.parse( schema );
  l_properties := l_schema.get_Object('properties');

  l_keys := l_properties.get_Keys();
  for i in 1..l_keys.count loop
    l_column := l_properties.get_Object( l_keys(i) );

    for c in (select ANNOTATION_NAME, ANNOTATION_VALUE 
      from user_annotations_usage
     where object_name=p_table_name 
       and object_type='TABLE' 
       and column_name=l_keys(i))
    loop
      l_column.put( c.ANNOTATION_NAME, c.ANNOTATION_VALUE );
    end loop;
  end loop;

  -- dbms_output.put_line( 'Schema: ' || l_schema.to_clob );

  return l_schema.to_json;
end;
/

select getAnnotatedJSONSchema('PRODUCTS');

-- GET : select getAnnotatedJSONSchema('PRODUCTS') as schema;
-- POST: insert into PRODUCTS_DV(data) values( 
--         json_transform(:body_text, RENAME '$.NAME'='_id')
--       );

create or replace json relational duality view products_dv as
products @insert
{
  _id: NAME
  PRICE
  QUANTITY
};

-- Get JSON Schema from JSON Relational Duality View
select dbms_json_schema.describe('PRODUCTS_DV');

-- Insert JSON in a Relational table (Bridging the Gap...)
-- by using the JSON Relational Duality View
insert into PRODUCTS_DV(data) values( 
    json_transform( '{"NAME": "Other nice product", 
                      "PRICE": 5, 
                      "QUANTITY": 10}', 
                    RENAME '$.NAME' = '_id'
    )
);
commit;

select * from products_dv;
select * from products;


-- validate data
select json{*} as data,
  dbms_json_schema.is_valid( 
      json{*}, 
      (select dbms_json_schema.describe('PRODUCTS')) 
  ) = 1 as is_valid
from products;

-- PRECHECK constraint
alter table products modify constraint 
      strictly_positive_price precheck;
alter table products modify constraint 
      non_negative_quantity precheck;

-- Now disable the constraints at the database level
-- They are checked in the clients
--
-- /!\ Warning: do that at your own risks!
alter table products modify constraint 
      strictly_positive_price disable;
alter table products modify constraint 
      non_negative_quantity disable;

-- Check constraints still present inside the JSON Schema
select dbms_json_schema.describe( 'PRODUCTS' );


insert into products (name, price, quantity)
values ('Bad product', 0, -1);
commit;

select * from products;

BEGIN
  ORDS.ENABLE_SCHEMA(
      p_enabled             => TRUE,
      p_schema              => 'LOIC',
      p_url_mapping_type    => 'BASE_PATH',
      p_url_mapping_pattern => 'loic',
      p_auto_rest_auth      => FALSE);
    
  ORDS.DEFINE_MODULE(
      p_module_name    => 'loic',
      p_base_path      => '/schema_repository/',
      p_items_per_page => 25,
      p_status         => 'PUBLISHED',
      p_comments       => NULL);

  ORDS.DEFINE_TEMPLATE(
      p_module_name    => 'loic',
      p_pattern        => 'products',
      p_priority       => 0,
      p_etag_type      => 'HASH',
      p_etag_query     => NULL,
      p_comments       => NULL);

  ORDS.DEFINE_HANDLER(
      p_module_name    => 'loic',
      p_pattern        => 'products',
      p_method         => 'GET',
      p_source_type    => 'json/item',
      p_mimes_allowed  => NULL,
      p_comments       => NULL,
      p_source         => 
'select getAnnotatedJSONSchema(''PRODUCTS'') as schema');

  ORDS.DEFINE_HANDLER(
      p_module_name    => 'loic',
      p_pattern        => 'products',
      p_method         => 'POST',
      p_source_type    => 'plsql/block',
      p_mimes_allowed  => NULL,
      p_comments       => NULL,
      p_source         => 
'begin
  OWA_UTIL.mime_header(''application/json'', TRUE);
  insert into PRODUCTS_DV(data) values( json_transform(:body_text, RENAME ''$.NAME'' = ''_id'') );
  commit;
  htp.p(''{}'');
  :status_code := 201;
exception when others then :status_code := 409;
end;');
        
COMMIT;

END;

/