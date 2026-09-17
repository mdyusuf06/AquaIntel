with open('../AquaIntel Backend/main.py', 'r', encoding='utf-8') as f:
    code = f.read()

chat_endpoint = '''

class ChatMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str

class AdvisorChatPayload(BaseModel):
    survey_id: str
    message: str
    history: List[ChatMessage] = []


@app.post("/mission-advisor/chat")
async def mission_advisor_chat(payload: AdvisorChatPayload):
    system_prompt = (
        "You are AquaIntel Copilot, an expert marine recovery and environmental impact advisor. "
        "You assist survey operators with follow-up questions about detected underwater objects, "
        "ecological risks, retrieval strategies, and safety protocols. "
        "Be concise, practical, and evidence-based. Do NOT output JSON — respond in plain, clear prose."
    )
    messages = [{"role": "system", "content": system_prompt}]
    for m in payload.history:
        messages.append({"role": m.role, "content": m.content})
    messages.append({"role": "user", "content": payload.message})

    try:
        client = AsyncGroq(api_key=os.getenv("GROQ_API_KEY", "mock_key"))
        chat_completion = await client.chat.completions.create(
            messages=messages,
            model="llama-3.1-70b-versatile",
            temperature=0.3,
            max_tokens=400
        )
        reply = chat_completion.choices[0].message.content.strip()
    except Exception as e:
        reply = f"Copilot unavailable: {str(e)}. Please try again shortly."

    return {"reply": reply, "survey_id": payload.survey_id}

'''

code = code.replace('\n@app.get("/surveys/{id}/summary")', chat_endpoint + '@app.get("/surveys/{id}/summary")')

with open('../AquaIntel Backend/main.py', 'w', encoding='utf-8') as f:
    f.write(code)

print("Backend patched: /mission-advisor/chat added")
