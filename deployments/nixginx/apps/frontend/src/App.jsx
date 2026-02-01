import { useState } from 'react'
import { greeting } from 'shared'

export default function App() {
  const [status, setStatus] = useState(null)
  const [loading, setLoading] = useState(false)

  const fetchStatus = async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/status')
      setStatus(await res.json())
    } catch (err) {
      setStatus({ error: err.message })
    }
    setLoading(false)
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100">
      <div className="text-center">
        <h1 className="text-4xl font-bold text-gray-900">Hello, World!</h1>
        <p className="mt-2 text-gray-600">{greeting}</p>

        <div className="mt-8">
          <button
            onClick={fetchStatus}
            disabled={loading}
            className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? 'Loading...' : 'Check Server Status'}
          </button>
        </div>

        {status && (
          <div className="mt-4 p-4 bg-white rounded shadow text-left inline-block">
            {status.error ? (
              <p className="text-red-600">Error: {status.error}</p>
            ) : (
              <dl className="space-y-1 text-sm">
                <div className="flex gap-2">
                  <dt className="text-gray-500">Status:</dt>
                  <dd className="font-mono text-green-600">{status.status}</dd>
                </div>
                <div className="flex gap-2">
                  <dt className="text-gray-500">Hostname:</dt>
                  <dd className="font-mono">{status.hostname}</dd>
                </div>
                <div className="flex gap-2">
                  <dt className="text-gray-500">Platform:</dt>
                  <dd className="font-mono">{status.platform}</dd>
                </div>
                <div className="flex gap-2">
                  <dt className="text-gray-500">Node:</dt>
                  <dd className="font-mono">{status.node}</dd>
                </div>
                <div className="flex gap-2">
                  <dt className="text-gray-500">Uptime:</dt>
                  <dd className="font-mono">{status.uptime}s</dd>
                </div>
                <div className="flex gap-2">
                  <dt className="text-gray-500">Memory:</dt>
                  <dd className="font-mono">{status.memory} MB</dd>
                </div>
              </dl>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
