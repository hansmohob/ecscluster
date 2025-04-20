import boto3
import json

class BedrockAnalyzer:
    def __init__(self):
        self.bedrock = boto3.client('bedrock-runtime')
        self.model_id = "anthropic.claude-v2"

    def analyze_logs(self, logs):
        """
        Analyze logs using Bedrock
        """
        try:
            # Format logs for analysis
            log_text = self._format_logs(logs)
            
            # Create prompt
            prompt = f"""You are an expert DevOps engineer analyzing .NET application logs.
            Please analyze these logs and identify:
            1. Any errors or issues
            2. Performance patterns
            3. Potential problems
            4. Recommended actions

            Logs:
            {log_text}

            Provide a clear, concise analysis with specific recommendations.
            """

            response = self.bedrock.invoke_model(
                modeodelId=self.model_id,
                body=json.dumps({
                    "prompt": prompt,
                    "max_tokens": 500,
                    "temperature": 0.7
                })
            )

            return json.loads(responsonse['body'].read())

        except Exception as e:
            print(f"Error analyzing logs: {str(e)}")
            return "Error analyzing logs"

    def _format_logs(self, logs):
        """Format logs for better analysis"""
        return "\n".join([
            f"{log.get('timestamp', '')}: {log.get('message', '')}"
            for log in logs
        ])