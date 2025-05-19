create json collection table customers;

insert /*+ append */ into customers(data)
select json { 'name' : 'Customer ' || level,
              'data' : dbms_random.string('X',4000),
              'active' : case when dbms_random.value < 0.05 then true else false end } from dual connect by level <= 100000;
commit;

-- do several times
insert /*+ append */ into customers(data)
select json_transform(data, set '$.active' = false, set '$._id' = json_id('OID')) from customers;
commit;

select /*+ NOPARALLEL OPT_PARAM('cell_offload_processing' 'false') */ count(*) from customers
where json_exists(data, '$.active?(@ == true)');

-- offload!
select /*+ NOPARALLEL OPT_PARAM('cell_offload_processing' 'true') */ count(*) from customers
where json_exists(data, '$.active?(@ == true)');