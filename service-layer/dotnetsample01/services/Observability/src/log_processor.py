import boto3
import datetime

class LogProcessor:
    def __init__(self):
        self.logs_client = boto3.client('logs')
        self.log_group = "/aws/eks/msn-eks-cluster/cluster"  # Adjust as needed

    def get_logs(self, hours_ago=1):
        """
        Get logs from CloudWatch with pagination handling
        """
        end_time = datetime.datetime.now()
        start_time = end_time - datetime.timedelta(hours=hours_ago)

        logs = []
        paginator = self.logs_client.get_paginator('filter_log_events')
        
        try:
            for page in paginator.paginate(
                logGroupName=self.log_group,
                startTime=int(start_time.timestamp() * 1000),
                endTime=int(end_time.timestamp() * 1000),
                limit=10000  # Max per request
            ):
                logs.extend(page.get('events', []))
                if len(logs) >= 10000:  # Respect CloudWatch Logs Insights limit
                    break
                    
        except Exception as e:
            print(f"Error fetching logs: {str(e)}")
            return []

        return logs