import Fastify from 'fastify'
import { greeting } from 'shared'
import os from 'node:os'

const app = Fastify({ logger: true })
const startedAt = Date.now()

app.get('/hello', async () => {
  return { message: greeting }
})

app.get('/status', async () => {
  return {
    status: 'ok',
    hostname: os.hostname(),
    platform: os.platform(),
    node: process.version,
    uptime: Math.floor((Date.now() - startedAt) / 1000),
    memory: Math.round(process.memoryUsage().heapUsed / 1024 / 1024)
  }
})

app.listen({ port: 3000, host: '0.0.0.0' })
