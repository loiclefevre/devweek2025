
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