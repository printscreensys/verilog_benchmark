# Please install OpenAI SDK first: `pip3 install openai`
from dotenv import load_dotenv
from openai import OpenAI
import os

client = OpenAI(
    api_key=os.environ.get("GROQ_API_KEY"),
    base_url="https://api.groq.com/openai/v1",
)

with open("task_01/input.txt") as f:
    response = client.responses.create(
        input=f.read(),
        model="groq/compound",
    )

file_path = "tmp/output.v"
os.makedirs(os.path.dirname(file_path), exist_ok=True)

with open(file_path, "w") as f:
    f.write(response.output_text)
