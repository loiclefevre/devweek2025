-- SELECT_AI.SQL

---------------------------------------------------------------
-- External JSON data using mle-js-fetch module
create or replace mle module json_fetch
language javascript as
import "mle-js-fetch";
export async function fetchJSONData(url) {
    if (url === undefined || url.length < 0) {
        throw Error("please provide a valid URL");
    }
    const response = await fetch(url);
    if (! response.ok) {
        throw new Error(`An error occurred: ${response.status}`);
    }
    return await response.json();
}
/

-- Fonction PL/SQL pour utilisation en SQL
create or replace function fetchJSONData( p_url varchar2 ) 
return json
as mle module json_fetch
signature 'fetchJSONData';
/

-- Exemple d'accès
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => 'opendata.paris.fr',
        ace  =>  xs$ace_type(
            privilege_list => xs$name_list('http'),
            principal_name => USER,
            principal_type => xs_acl.ptype_db
        )
    );
END;
/

set define §;
set verify off;
with my_data(doc) as (select treat(fetchJSONData('https://opendata.paris.fr/api/records/1.0/search/?dataset=arbresremarquablesparis&q=&lang=en&rows=200&facet=genre&facet=espece&facet=stadedeveloppement&facet=varieteoucultivar&facet=dateplantation&facet=libellefrancais') as json))
--select doc from my_data;
select to_char(j.birthday,'DD/MM/YYYY') as birthday,
       j.name,
       j.location
  from my_data nested doc columns ( nested records[*] columns (
  birthday timestamp path '$.fields.arbres_dateplantation.timestamp()',
  name path '$.fields.arbres_libellefrancais',
  location path '$.fields.arbres_arrondissement'
) ) j
order by j.birthday fetch first 3 rows only;

---------------------------------------------------------------
-- Other way using solely SQL
set define §;
set verify off;
select *
from external (
    (data json)
    type ORACLE_BIGDATA
    access parameters (com.oracle.bigdata.fileformat = jsondoc)
    location ('https://opendata.paris.fr/api/records/1.0/search/?dataset=arbresremarquablesparis&q=&lang=en&rows=200&facet=genre&facet=espece&facet=stadedeveloppement&facet=varieteoucultivar&facet=dateplantation&facet=libellefrancais')
);

---------------------------------------------------------------
-- JSON schemas

-- setup
exec ords.enable_schema;

-- cleanup
alter session set NLS_TIMESTAMP_FORMAT='RR-MM-DD"T"HH24:MI:SS"Z"';
set linesize 65;
set long 10000;
set pagesize 1;
drop table if exists blog_posts purge;
drop table if exists products purge;
drop view if exists products_dv;
drop table if exists posts purge;
drop domain if exists BlogPost;
drop table if exists orders purge;
drop table if exists test purge;

-------------------------------------------------------------
-- Use case 1: structure discovery with JSON Data Guide
-------------------------------------------------------------

create table blog_posts (
  data json -- BINARY JSON
);

insert into blog_posts(data) values(
    json {
        'title': 'New Blog Post',
        'content': 'This is the content of the blog post...',
        'publishedDate': '2023-08-25T15:00:00Z',
        'author': {
            'username': 'authoruser',
            'email': 'author@example.com'
        },
        'tags': ['Technology', 'Programming']
    }
);
commit;

-- SQL dot notation to navigate in JSON hierarchy
select p.data.title, 
       p.data.author.username.string() as username,
       p.data.tags[1].string() as "array_field[1]"
  from blog_posts p;

-- Nothing prevents inserting bad data!
insert into blog_posts values('{"garbageDocument":true}');
commit;

select data from blog_posts;

-- JSON Schema to the rescue, but how to create it? 
-- Ask the database!
-- Remark: you need data!
select json_dataguide(
    data, 
    dbms_json.format_schema,
    dbms_json.pretty
) as json_schema
from blog_posts;

-------------------------------------------------------------
-- Use case 2: Data Validation
-------------------------------------------------------------

-- Validate the generated JSON schema
select dbms_json_schema.is_schema_valid( 
    (
      -- Generate JSON Data Guide/Schema from data column
      select json_dataguide(
        data,
        dbms_json.format_schema,
        dbms_json.pretty
      ) as json_schema
      from blog_posts
    ) 
) = 1 as is_schema_valid;

-- Validate current JSON data with a simple JSON schema
select data from blog_posts;

select dbms_json_schema.validate_report( data,
  json( '{
          "type" : "object",
          "properties" :
          { 
            "tags" :
            {
              "type" : "array",
              "items" :
              {
                "type" : "string"
              }
            }
          }
        }'
    )
  ) as report
from blog_posts;

-- Validation *REPORT* with a JSON schema on all the data
-- Source: https://json-schema.org/learn/json-schema-examples#blog-post
select dbms_json_schema.validate_report( 
  data,
  json('{
    "$id": "https://example.com/blog-post.schema.json",
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "description": "A representation of a blog post",
    "type": "object",
    "required": ["title", "content", "author"],
    "properties": {
      "title": {
        "type": "string"
      },
      "content": {
        "type": "string"
      },
      "publishedDate": {
        "type": "string",
        "format": "date-time"
      },
      "author": {
        "$ref": "https://example.com/user-profile.schema.json"
      },
      "tags": {
        "type": "array",
        "items": {
          "type": "string"
        }
      }
    },
    "$def": {
      "$id": "https://example.com/user-profile.schema.json",
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "description": "A representation of a user profile",
      "type": "object",
      "required": ["username", "email"],
      "properties": {
        "username": {
          "type": "string"
        },
        "email": {
          "type": "string",
          "format": "email"
        },
        "fullName": {
          "type": "string"
        },
        "age": {
          "type": "integer",
          "minimum": 0
        },
        "location": {
          "type": "string"
        },
        "interests": {
          "type": "array",
          "items": {
            "type": "string"
          }
        }
      }
    }
  }')
) as report
from blog_posts;

-- Validate data only (no detailed report)
select dbms_json_schema.is_valid( 
    data,
    json('{
        "$id": "https://example.com/blog-post.schema.json",
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "description": "A representation of a blog post",
        "type": "object",
        "required": ["title", "content", "author"],
        "properties": {
            "title": {
            "type": "string"
            },
            "content": {
            "type": "string"
            },
            "publishedDate": {
            "type": "string",
            "format": "date-time"
            },
            "author": {
            "$ref": "https://example.com/user-profile.schema.json"
            },
            "tags": {
            "type": "array",
            "items": {
                "type": "string"
            }
            }
        },
        "$def": {
            "$id": "https://example.com/user-profile.schema.json",
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "description": "A representation of a user profile",
            "type": "object",
            "required": ["username", "email"],
            "properties": {
            "username": {
                "type": "string"
            },
            "email": {
                "type": "string",
                "format": "email"
            },
            "fullName": {
                "type": "string"
            },
            "age": {
                "type": "integer",
                "minimum": 0
            },
            "location": {
                "type": "string"
            },
            "interests": {
                "type": "array",
                "items": {
                "type": "string"
                }
            }
            }
        }
        }')
  ) = 1 as is_valid, 
  data 
from blog_posts;

-- Also create a JSON schema: from a Relational table!
select dbms_json_schema.describe( 'BLOG_POSTS' );

---------------------------------------------------------------
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

set define §
set verify off
create or replace mle module json_schema_module
language javascript as
export function getAnnotatedJSONSchema(tableName) {
    if (tableName == null) {
        throw new Error(`Parameter tableName either not provided or null`);
    }

    try {
        // Get JSON Schema for tableName
        const schema = session.execute(
            `select dbms_json_schema.describe( :table_name ) as "schema"`,
            [ tableName ], { outFormat: oracledb.OUT_FORMAT_OBJECT } ).rows[0].schema;
            
        // Get JSON Schema array properties
        const properties = schema.properties;

        // Retrieve all column annotations from dictionnary...
        for(let annotationRow of (session.execute(
            `select COLUMN_NAME, ANNOTATION_NAME, ANNOTATION_VALUE 
                from user_annotations_usage
                where object_name=:table_name
                and object_type='TABLE' 
                and json_exists( :properties, '$?(@ == $B0)' PASSING column_name AS "B0" )`,
            { 
                table_name:{
                    dir: oracledb.BIND_IN,
                    val: tableName,
                    type: oracledb.STRING
                },
                properties:{
                    dir: oracledb.BIND_IN,
                    val: Object.keys(properties),
                    type: oracledb.DB_TYPE_JSON
                }
            }, { outFormat: oracledb.OUT_FORMAT_OBJECT } ).rows) ) {
                // ...and augment the existing properties
                const columnDoc = properties[annotationRow.COLUMN_NAME];
                columnDoc[ annotationRow.ANNOTATION_NAME ] = annotationRow.ANNOTATION_VALUE;
            }

        // Returns annotated JSON Schema
        return schema;
    } catch (err) {
        return {"Error": err.message};
    }

    return {};
}
/

select dbms_json_schema.describe( 'PRODUCTS' ) as schema;

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

-- SEE ORDS_MODULES.SQL

-- Insert JSON in a Relational table (Bridging the Gap...)
-- by using the JSON Relational Duality View
insert into PRODUCTS_DV(data) values( 
    json {'_id' : 'Other nice product', 
          'PRICE' : 5, 
          'QUANTITY' : 10} );
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

-- Introducing Data Use Case Domains
create domain if not exists jsonb as json;

create table test ( 
  data jsonb -- JSON alias
);

-- Another way to validate JSON data: Data Use Case Domain
-- drop table if exists posts purge;
-- drop domain if exists BlogPost;
create domain if not exists BlogPost as json
validate '{
        "$id": "https://example.com/blog-post.schema.json",
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "description": "A representation of a blog post",
        "type": "object",
        "required": ["title", "content", "author"],
        "properties": {
            "title": {
            "type": "string"
            },
            "content": {
            "type": "string"
            },
            "publishedDate": {
            "type": "string",
            "format": "date-time"
            },
            "author": {
            "$ref": "https://example.com/user-profile.schema.json"
            },
            "tags": {
            "type": "array",
            "items": {
                "type": "string"
            }
            }
        },
        "$def": {
            "$id": "https://example.com/user-profile.schema.json",
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "description": "A representation of a user profile",
            "type": "object",
            "required": ["username", "email"],
            "properties": {
            "username": {
                "type": "string"
            },
            "email": {
                "type": "string",
                "format": "email"
            },
            "fullName": {
                "type": "string"
            },
            "age": {
                "type": "integer",
                "minimum": 0
            },
            "location": {
                "type": "string"
            },
            "interests": {
                "type": "array",
                "items": {
                "type": "string"
                }
            }
            }
        }
        }';

-- Now use the Domain as a new column data type!
create table posts ( content BlogPost );

-- fails
insert into posts values (json{ 'garbageDocument' : true });

-- works
insert into posts values (
    json {
        'title': 'Best brownies recipe ever!',
        'content': 'Take chocolate...',
        'publishedDate': '2025-05-21T13:00:00Z',
        'author': {
            'username': 'Loïc',
            'email': 'loic@email.com'
        },
        'tags': ['Cooking', 'Chocolate', 'Cocooning']
    }
);
commit;

-- Now let's look at the publishedDate field...
select p.content.publishedDate from posts p;

-- ...its binary encoded data type is 'string'
select p.content.publishedDate.type() as type from posts p;

-------------------------------------------------------------
-- Use case 3: Performance Improvement
-------------------------------------------------------------

drop table if exists posts purge;

drop domain if exists BlogPost;

-- Recreate the Domain with CAST/Type coercion enabled
create domain BlogPost as json
validate CAST using '{
        "$id": "https://example.com/blog-post.schema.json",
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "description": "A representation of a blog post",
        "type": "object",
        "required": ["title", "content", "author"],
        "properties": {
            "title": {
            "type": "string"
            },
            "content": {
            "type": "string"
            },
            "publishedDate": {
"extendedType": "timestamp",
            "format": "date-time"
            },
            "author": {
            "$ref": "https://example.com/user-profile.schema.json"
            },
            "tags": {
            "type": "array",
            "items": {
                "type": "string"
            }
            }
        },
        "$def": {
            "$id": "https://example.com/user-profile.schema.json",
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "description": "A representation of a user profile",
            "type": "object",
            "required": ["username", "email"],
            "properties": {
            "username": {
                "type": "string"
            },
            "email": {
                "type": "string",
                "format": "email"
            },
            "fullName": {
                "type": "string"
            },
            "age": {
                "type": "integer",
                "minimum": 0
            },
            "location": {
                "type": "string"
            },
            "interests": {
                "type": "array",
                "items": {
                "type": "string"
                }
            }
            }
        }
        }';

create table posts ( content BlogPost );

-- We can retrieve the JSON schema associated to the column
-- via the Data Use Case Domain
select dbms_json_schema.describe( 'POSTS' );

-- works
insert into posts values (
    '{
        "title": "Best brownies recipe ever!",
        "content": "Take chocolate...",
        "publishedDate": "2025-05-21T13:00:00Z",
        "author": {
            "username": "Loïc",
            "email": "loic@emil.com"
        },
        "tags": ["Cooking", "Chocolate", "Cocooning"]
    }'
);
commit;

-- Now let's look at the publishedDate field...
select p.content.publishedDate from posts p;

-- ...its binary encoded data type is 'timestamp'
select p.content.publishedDate.type() from posts p;

-- I can add 5 days to this date...
select p.content.publishedDate.timestamp() + interval '5' day
from posts p;

-------------------------------------------------------------
-- Use case 4: Relational Model Evolution
-------------------------------------------------------------
-- drop table if exists orders purge;

create table orders ( j json );

insert into orders(j) values (
  json {'firstName':'Loïc', 'address' : 'Paris'}
);
commit;

select j from orders;

-- drop index s_idx force;

-- Create a Full-Text Search index for JSON with Data Guide
-- enabled and add_vc stored procedure enabled to change
-- table structure: add virtual column for JSON fields,
-- helpful for Analytics => you directly have the existing
-- JSON fields listed as columns!
create search index s_idx on orders(j) for json
parameters('dataguide on change add_vc');

select * from orders;

insert into orders(j) values (
  json {'firstName':'Loïc', 'address' : 'Paris', 
        'vat': false}
);
commit;

select * from orders;

insert into orders(j) values (
  json {'firstName':'Loïc', 'address' : 'Paris', 
        'vat': false, 'tableEvolve': true}
);
commit;

select * from orders;

---------------------------------------------------------------
-- Perfs Offloading Autonomous Database / Exadata

-- SEE PERFS_OFFLOADING.SQL

---------------------------------------------------------------
-- MongoDB API, Aggregation Pipeline
db.CUSTOMERS.aggregate( [
  {
    $match: {
      name: { $regex: "customer 1", "$options" : "i" }
    }
  },
  {
    $group: {
      _id: {
        active: "$active"
      },
      count: {
        $count: {}
      }
    }
  }
], {hint:{$service:"HIGH"}} );

db.CUSTOMERS.aggregate( [
  {
    $match: {
      name: { $regex: "customer 1", "$options" : "i" }
    }
  },
  {
    $group: {
      _id: {
        active: "$active"
      },
      count: {
        $count: {}
      }
    }
  }
], {hint:{$service:"HIGH"}} ).explain();


db.aggregate( [
    {
      $external : 'https://raw.githubusercontent.com/neelabalan/mongodb-sample-dataset/main/sample_mflix/movies.json'
    },
    {
      $out: 'movies'
    }
], 
{ hint:{$service:"HIGH"} }
);
