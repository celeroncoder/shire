import type { IpcInvokeMap, IpcEventMap } from "./ipc-types";

export async function ipcInvoke<K extends keyof IpcInvokeMap>(
  channel: K,
  ...args: IpcInvokeMap[K]["args"] extends void ? [] : [IpcInvokeMap[K]["args"]]
): Promise<IpcInvokeMap[K]["result"]> {
  return window.api.invoke(channel, ...args) as Promise<IpcInvokeMap[K]["result"]>;
}

export function ipcOn<K extends keyof IpcEventMap>(
  channel: K,
  callback: (data: IpcEventMap[K]) => void
): () => void {
  return window.api.on(channel, (...args: unknown[]) => {
    callback(args[0] as IpcEventMap[K]);
  });
}
