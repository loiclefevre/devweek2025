-- Minimum of 16 ECPUs
-- As ADMIN
BEGIN
    DBMS_INMEMORY_ADMIN.SET_SGA_PERCENTAGE(70);
END;
/

-- As user
alter table <json collection table> NO INMEMORY;

alter table <json collection table> INMEMORY priority critical
INMEMORY MEMCOMPRESS FOR CAPACITY LOW (data) 
NO INMEMORY (resid, etag);

begin
 DBMS_INMEMORY.REPOPULATE(
   schema_name => user,
   table_name => '<json collection table>',
   force => true );
end;
/

-- As ADMIN, track column store loading process
SELECT inmemory_size/1024/1024 as "columnar_size", bytes/1024/1024 as "size", bytes_not_populated/1024/1024 as "remaining", populate_status as "status",
inmemory_size/(bytes-bytes_not_populated)
FROM   GV$IM_SEGMENTS s;

SELECT table_name,
       segment_column_id,
       column_name,
       inmemory_compression
FROM   v$im_column_level
WHERE  owner = '<owner>'
and    table_name = '<json collection table>'
ORDER BY segment_column_id;
