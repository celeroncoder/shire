import { fileTypeFromBuffer } from "file-type";
import fs from "node:fs/promises";

const SAMPLE_SIZE = 4100; // enough bytes for magic number detection

export async function isBinary(filePath: string): Promise<boolean> {
  const handle = await fs.open(filePath, "r");
  try {
    const buffer = Buffer.alloc(SAMPLE_SIZE);
    const { bytesRead } = await handle.read(buffer, 0, SAMPLE_SIZE, 0);

    if (bytesRead === 0) {
      return false;
    }

    const result = await fileTypeFromBuffer(buffer.subarray(0, bytesRead));

    if (result === undefined) {
      return false;
    }

    if (result.mime.startsWith("text/")) {
      return false;
    }

    return true;
  } finally {
    await handle.close();
  }
}
