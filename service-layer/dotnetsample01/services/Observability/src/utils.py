from datetime import datetime

def format_timestamp(ms_timestamp):
    """Convert millisecond timestamp to readable format"""
    return datetime.fromtimestamp(ms_timestamp/1000).strftime('%Y-%m-%d %H:%M:%S')

def categorize_log_level(message):
    """Determine log level from message"""
    message = message.lower()
    if 'error' in message:
        return 'ERROR'
    elif 'warn' in message:
        return 'WARNING'
    elif 'info' in message:
        return 'INFO'
    return 'DEBUG'