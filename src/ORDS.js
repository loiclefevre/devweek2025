import axios from 'axios';

function ORDS() {}

ORDS.prototype.getSchema = async function() {
  return await axios.get('https://G04882E973A17CF-DEVWEEK.adb.eu-paris-1.oraclecloudapps.com/ords/loic/schema_repository/products', {}, { headers: { "content-type": "application/json-www-form-urlencoded" } })
    .then( res => res.data.schema )
    .catch((err) => { console.error(err); });
}

ORDS.prototype.insertNewProduct = async function(productJSON) {
  return await axios.post('https://G04882E973A17CF-DEVWEEK.adb.eu-paris-1.oraclecloudapps.com/ords/loic/schema_repository/products', productJSON, { headers: { "content-type": "application/json-www-form-urlencoded" } })
    .then( res => res )
    .catch((err) => { console.error(err); });
}

export default new ORDS();
