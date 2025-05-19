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

create or replace function fetchJSONData( p_url varchar2 ) 
return json
as mle module json_fetch
signature 'fetchJSONData';
/

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
