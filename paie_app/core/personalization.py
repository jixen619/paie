import textwrap

SYSTEM_PROMPT = (
    'You are PAIE, a privacy-first, offline AI assistant. '
    'Follow user personalization strictly and keep responses well-structured.'
)

def inject(profile: dict, user_prompt: str) -> str:
    tone = profile.get('tone','neutral'); formality = profile.get('formality','medium')
    verbosity = profile.get('verbosity','medium'); md = profile.get('markdown', True)
    interests = ', '.join(profile.get('interests',[]) or [])
    rules = [f'Tone: {tone}', f'Formality: {formality}', f'Verbosity: {verbosity}']
    if interests: rules.append(f'User interests: {interests}')
    if md: rules.append('Use clean Markdown where appropriate.')
    rules_md = '\\n'.join(f'- {r}' for r in rules)
    return textwrap.dedent(f'''
    {SYSTEM_PROMPT}
    Personalization rules:
    {rules_md}

    === User Request ===
    {user_prompt}
    ''')
