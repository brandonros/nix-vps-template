import Fastify from 'fastify'
import { greeting } from 'shared'

const app = Fastify({ logger: true })

app.get('/hello', async () => {
  return { message: greeting }
})

app.listen({ port: 3000, host: '0.0.0.0' })
