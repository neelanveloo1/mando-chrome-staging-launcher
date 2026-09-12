import {mkdir, cp} from 'node:fs/promises';
await mkdir('dist', {recursive: true});
await cp('web', 'dist', {recursive: true});
