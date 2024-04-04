const axios = require('axios')
/**
 * Small description of your action
 * @title The title displayed in the flow editor
 * @category Custom
 * @author Your_Name
 * @param {string} name - An example string variable
 * @param {any} value - Another Example value
 */

//temp.payment_info = 'sssssssssuka'
const myAction = async () => {
  const conversation_id = event.payload.metadata.event.conversation.id
  let data = JSON.stringify({
    conversation_id: conversation_id
  })

  let config = {
    method: 'post',
    maxBodyLength: Infinity,
    url: 'http://host.docker.internal:5000/v1/botpress/webhook/show',
    headers: {
      'Content-Type': 'application/json'
    },
    data: data
  }

  const resp = await axios.request(config)

  temp.payment_info = resp //data.amount
}

return myAction()
