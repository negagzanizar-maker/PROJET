import type { Device } from './types'

export function formatMac(value: string) {
  const compact = value.replace(/[:-]/g, '').toUpperCase()
  return compact.length === 12 ? compact.match(/.{2}/g)?.join(':') ?? compact : value
}

export function formatDate(value: string | null) {
  return value ? new Date(value).toLocaleString('fr-FR') : '—'
}

export function deviceName(devices: Device[], deviceId: string) {
  return devices.find((device) => device.id === deviceId)?.displayName ?? deviceId
}

export function optionalUtc(value: FormDataEntryValue | null) {
  const text = typeof value === 'string' ? value.trim() : ''
  return text ? new Date(text).toISOString() : null
}
