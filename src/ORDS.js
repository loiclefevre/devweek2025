import axios from 'axios';

function ORDS() {}

ORDS.prototype.getSchema = async function() {
  return await axios.get(process.env.REACT_APP_ORDS_URL+'/loic/schema_repository/products', {}, { headers: { "content-type": "application/json" } })
    .then( res => res.data.schema )
    .catch((err) => { console.error(err); });
}

ORDS.prototype.insertNewProduct = async function(productJSON) {
  return await axios.post(process.env.REACT_APP_ORDS_URL+'/loic/schema_repository/products', productJSON, { headers: { "content-type": "application/json" } })
    .then( res => res )
    .catch((err) => { console.error(err); });
}

export default new ORDS();
