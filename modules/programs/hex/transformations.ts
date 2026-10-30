function transformProse(text: string, transform: (part: string, last: boolean) => string): string {
  // Keep code, URLs, and quoted text unchanged.
  const parts = text.split(/(```[\s\S]*?```|`[^`\n]*`|https?:\/\/[^\s]+|"[^"\n]*"|“[^”\n]*”)/g)
  return parts
    .map((part, index) => index % 2 === 0 ? transform(part, index === parts.length - 1) : part)
    .join("")
}

export function cleanSpeech(text: string): string {
  return transformProse(text, (part) => part
    .replace(/(^|,[ \t]*)you[ \t]+know(?:,[ \t]*|(?=[.!?]?[ \t]*$))/gim,
      (_filler, prefix: string) => prefix ? " " : "")
    .replace(/(?:,[ \t]*)?(?<![\p{L}\p{N}_/'-])(?:um+|uh+|erm+)(?![\p{L}\p{N}_/'-])(?:[ \t]*[,;:.!?])?[ \t]*/giu,
      (filler) => filler.startsWith(",") ? " " : "")
    .replace(/\b(i|i'm|i’m|i'll|i’ll|and|but)(?:[ \t]*,?[ \t]+\1\b)+/gi, "$1")
    .replace(/[ \t]+([,.;:!?])/g, "$1")
    .replace(/[ \t]{2,}/g, " "))
    .trim()
}

export function slackStyle(text: string): string {
  return transformProse(text.trimEnd(), (part, last) => {
    const lower = part.toLowerCase()
    return last ? lower.replace(/(?<!\.)\.$/, "") : lower
  })
}
