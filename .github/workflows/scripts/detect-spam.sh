#!/usr/bin/bash

#_issue_url="https://github.com/cli/cli/issues/11236"  # a template copy
# _issue_url="https://github.com/cli/cli/issues/11223"  # a link
#_issue_url="https://github.com/cli/cli/issues/11242" # two words

#_issue_url=https://github.com/cli/cli/issues/11272 # legit, short
_issue_url=https://github.com/cli/cli/issues/11239 # legit, oss community

_issue_body="$(gh issue view $_issue_url --json body -q '.body')"
_issue_title="$(gh issue view $_issue_url --json title -q '.title')"

# _issue_body="gh issue create"

_prompt="title: $_issue_title

Body:

$_issue_body"

_system_prompt='
# Your role as a spam detection system

You are a spam detection AI. You determine if the provided GitHub issue is spam or not.

You''re going to answer the following questions based on the issue provided to you as a prompt, and project the answers to fields in the JSON response.

- Populate the `template_match_score` field of the response with a number between -1 to 10 where 0 means the issue is not an EXACT match of an issue template and 10 is an exact match of an issue template with no additional content. Respond with -1 if you are unsure.
- Populate the `github_unrelated_score` field of the response with a number between -1 to 10 where 0 means the issue is completely related to GitHub and 10 means the issue is completely unrelated to GitHub. Respond with -1 if you are unsure.
    - Similarity to an issue template DOES NOT indicate relatedness to GitHub.
- Populate the `cli_unrelated_score` field of the response with a number between -1 to 10 where 0 means the issue is completely related to GitHub CLI or other CLI tools and 10 means the issue is completely unrelated to GitHub CLI or other CLI tools. Respond with -1 if you are unsure.
    - Similarity to an issue template DOES NOT indicate relatedness to GitHub CLI or other CLI tools.
- Populate the `nonsense_score` field of the response with a number between -1 to 10 where 0 means the issue is completely sensible and 10 means the issue is complete nonsense. Respond with -1 if you are unsure.

For each field, you MUST provide a number. If you provide 0, that means the issue is less likely to be spam. If you provide 10, that means the issue is more likely to be spam.

You MUST provide -1 if you are unsure of the score to assign to a particular field.

## Response format

Respond with a JSON object the below schema:

```
{
    "template_match_score": 0,
    "github_unrelated_score": 0,
    "cli_unrelated_score": 0,
    "nonsense_score": 0
}
```

# Definitions of SPAM

## Project context

Issues related to the GitHub CLI tool are less likely to be spam.

This is the GitHub CLI (gh) project - a command-line tool for GitHub. Legitimate issues should be related to:

- Bug reports about the CLI tool functionality
- Feature requests for new CLI commands or improvements
- Documentation issues
- Installation or usage problems
- Questions about CLI behavior
- Sometimes GitHub-related issues that are relevant to the CLI context

## Special considerations

- Very short descriptions aren''t automatically spam if they contain relevant keywords or references.
- Foreign language content should be evaluated based on relevance, not just that the language is not English.
- Consider the effort required to write the issue - more effort usually indicates legitimacy.
- Template similarities should be weighted heavily as they often indicate low-effort submissions.

## Examples of legitimate content

Issues that match legitimate content are NOT spam.

- Clear description of a bug with steps to reproduce.
- Feature requests with detailed explanations and use cases.
- Documentation improvements with specific suggestions.
- Questions about usage with context and examples.
- Reports that reference specific code, files, or functionality.

## Examples of spam content

Issues that match spam content are likely spam.

- A description that is a copy of (or a small variation of) the issue templates defined under the "Issue templates" section below.
- An empty issue description.
- A description that contains only a single word or a few words, such as "bug", "help", "issue", "problem".
- A meaningless description that does not provide any useful information about the issue.
- A description that is just one or more links without any context or explanation.
- Generic placeholder text like "Lorem ipsum" or "test test test".
- Repetitive content (same word/phrase repeated multiple times).
- Content that appears to be copied from other sources without relevance to the project.
- Promotional content, advertisements, or unrelated marketing material.
- Content in languages that seem inappropriate for the project context.
- Issues that don''t relate to the project''s purpose (e.g., personal messages, off-topic discussions).

## Issue templates

Issues that exactly match issues templates defined below are likely spam.

Here are the issue templates already defined in the project:

'

# Append the issue templates to the system prompt.
_template_index=1
for template_file in .github/ISSUE_TEMPLATE/*.md; do
    if ! [[ -f "$template_file" ]]; then
        continue
    fi

    _template_content="$(cat "$template_file")"

    # Remove YAML front matter (everything between the first two --- lines)
    _template_content="$(echo "$_template_content" | sed '1,/^---$/d; /^---$/,$d')"

    _escaped_template="${_template_content//\`/\\\`}"
    _system_prompt="${_system_prompt}
### Template ${_template_index}
\`\`\`
${_escaped_template}
\`\`\`
"
    ((_template_index++))
done

_request_body_tmpl='
    {
        "response_format": {
            "type": "json_object"
        },
        "messages": [
            {
                "role": "system",
                "content": ""
            },
            {
                "role": "user",
                "content": ""
            }
        ],
        "model": "openai/o1"
    }
'

_request_body="$(jq --arg content "$_prompt" --arg system "$_system_prompt" '.messages[0].content = $system | .messages[1].content = $content' <<< "$_request_body_tmpl")"

_resp="$(curl --silent -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $(gh auth token)" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/json" \
  https://models.github.ai/inference/chat/completions \
  -d "$_request_body"
  )"

_result="$(jq -r '.choices[0].message.content' <<< "$_resp")"
echo "$_result"