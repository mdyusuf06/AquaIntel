import os
import groq
from dotenv import load_dotenv

load_dotenv(override=True)
api_key = os.getenv('GROQ_API_KEY')

client = groq.Groq(api_key=api_key)
try:
    models = client.models.list()
    print('Available models:')
    for m in models.data:
        print('-', m.id)
except Exception as e:
    print('Error:', e)
