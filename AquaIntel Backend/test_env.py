import os
from dotenv import load_dotenv

print('Before load_dotenv:', os.getenv('GROQ_API_KEY'))
load_dotenv()
print('After load_dotenv:', os.getenv('GROQ_API_KEY'))
load_dotenv(override=True)
print('After load_dotenv(override=True):', os.getenv('GROQ_API_KEY'))
