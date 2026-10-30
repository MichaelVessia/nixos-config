import assert from "node:assert/strict"
import test from "node:test"
import { cleanSpeech, slackStyle } from "./transformations.ts"

test("removes spoken fillers and accidental repeated conjunctions", () => {
  assert.equal(cleanSpeech("Um, I, uh, think I'll I'll check and and let you know."),
    "I think I'll check and let you know.")
  assert.equal(cleanSpeech("Um um, uh, erm. Ready?"), "Ready?")
  assert.equal(cleanSpeech("uh"), "")
})

test("keeps meaningful words, emphasis, and paragraph breaks", () => {
  const text = "I feel like this is really really good.\n\nI like it, but that that change failed."
  assert.equal(cleanSpeech(text), text)
  assert.equal(cleanSpeech("uh-huh, summer, human, and spectrum"),
    "uh-huh, summer, human, and spectrum")
})

test("keeps code, URLs, and quoted words unchanged", () => {
  const text = 'Um, use `UM` and https://Example.com/Um then say "um".\n```ts\nconst UM = "uh"\n```'
  assert.equal(cleanSpeech(text),
    'use `UM` and https://Example.com/Um then say "um".\n```ts\nconst UM = "uh"\n```')
  assert.equal(slackStyle('Use `MyAPI` at https://Example.com/Case.'),
    'use `MyAPI` at https://Example.com/Case.')
})

test("Slack style removes a final period but keeps questions and emphasis", () => {
  assert.equal(slackStyle(cleanSpeech("Um, I think it's ready. Can you check?")),
    "i think it's ready. can you check?")
  assert.equal(slackStyle("Looks good."), "looks good")
  assert.equal(slackStyle("Looks good!"), "looks good!")
  assert.equal(slackStyle("Maybe..."), "maybe...")
})
