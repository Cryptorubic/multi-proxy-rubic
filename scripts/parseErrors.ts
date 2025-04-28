import ABI from '../diamondABI/diamond.json'
import { keccak256 } from '@ethersproject/solidity'
import fs from 'fs'

const parsedErrors: { text: string; hash: string }[] = []

const errors = ABI.filter((entry) => {
  return entry.type === 'error'
})

for (const error of errors) {
  parsedErrors.push({
    text: <string>error.name,
    hash: keccak256(['string'], [error.name + '()']).slice(0, 10),
  })
}

fs.writeFile(
  './errors/errorsTextAndHash.json',
  JSON.stringify(parsedErrors, null, 2),
  { flag: 'wx' },
  function (err) {
    if (err) throw err
    console.log('Errors are parsed and written')
  }
)
