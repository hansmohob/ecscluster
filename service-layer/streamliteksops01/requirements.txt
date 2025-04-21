from datetime import datetime
import json
import os
import boto3
import streamlit as st

# Data directory for persistence
DATA_DIR = '/app/data'
CACHE_FILE = os.path.join(DATA_DIR, 'analysis_cache.json')

# Create data directory if it doesn't exist
os.makedirs(DATA_DIR, exist_ok=True)

# Log Groups
LOG_GROUPS = [
    "/aws/eks/msn-eks-cluster/cluster",
    "/aws/containerinsights/msn-eks-cluster/application",
    "/aws/containerinsights/msn-eks-cluster/performance"
]

# Model options with descriptions
MODEL_OPTIONS = {
    "Quick Analysis (Fastest)": "amazon.nova-sonic-v1:0",
    "Standard Analysis": "amazon.nova-lite-v1:0:24k",
    "Deep Analysis": "anthropic.claude-3-sonnet-20240229-v1:0",
    "Advanced Analysis (Slowest but most thorough)": "anthropic.claude-3-opus-20240229-v1:0"
}

# Initialize AWS clients
logs_client = boto3.client('logs')
bedrock = boto3.client('bedrock-runtime')

def get_logs(hours_ago=1, selected_groups=None):
    """Get logs from multiple CloudWatch log groups with pagination"""
    if selected_groups is None:
        selected_groups = LOG_GROUPS

    end_time = datetime.now()
    start_time = end_time - datetime.timedelta(hours=hours_ago)

    all_logs = []
    
    for log_group in selected_groups:
        try:
            paginator = logs_client.get_paginator('filter_log_events')
            for page in paginator.paginate(
                logGroupName=log_group,
                startTime=int(start_time.timestamp() * 1000),
                endTime=int(end_time.timestamp() * 1000),
                limit=10000
            ):
                for event in page.get('events', []):
                    event['logGroup'] = log_group  # Add source information
                    all_logs.append(event)
                if len(all_logs) >= 10000:
                    break
                    
        except Exception as e:
            st.warning(f"Error fetching logs from {log_group}: {str(e)}")
            continue

    # Sort all logs by timestamp
    all_logs.sort(key=lambda x: x['timestamp'])
    return all_logs

def analyze_with_bedrock(logs, model_id):
    """Analyze logs using Bedrock with correlation analysis"""
    # Group logs by their source
    logs_by_group = {}
    for log in logs:
        group = log.get('logGroup', 'unknown')
        if group not in logs_by_group:
            logs_by_group[group] = []
        logs_by_group[group].append(log)

    # Format logs showing their sources
    log_text = ""
    for group, group_logs in logs_by_group.items():
        log_text += f"\nLogs from {group}:\n"
        log_text += "\n".join([
            f"{datetime.fromtimestamp(log['timestamp']/1000).strftime('%Y-%m-%d %H:%M:%S')}: {log['message']}"
            for log in group_logs
        ])

    prompt = f"""You are an expert DevOps engineer with deep knowledge of .NET applications running on EKS. 
    You understand CloudWatch metrics, container logs, and Kubernetes operations.

    Context:
    - Working with EKS cluster running .NET microservices
    - Healthy system: latency <200ms, CPU <80%, zero 5xx errors
    - Any deviation from these baselines indicates problems

    Please analyze these logs and identify:
    1. Patterns and correlations across different log sources
    2. Cause-and-effect relationships between events
    3. How control plane events relate to application behavior
    4. Performance patterns that span multiple components
    5. Root causes that might manifest in multiple places

    The logs are grouped by source for clarity.

    Logs:
    {log_text}

    Response format:
    1. Key Findings (clear, concise summary)
    2. Evidence (specific log entries supporting findings)
    3. Cross-Component Analysis (how different parts interact)
    4. Actionable Next Steps
    5. Similar Patterns (if you've seen this before)

    Keep responses focused and practical, like an experienced engineer would.
    """

    try:
        response = bedrock.invoke_model(
            modelId=model_id,
            body=json.dumps({
                "prompt": prompt,
                "max_tokens": 1000,
                "temperature": 0.7
            })
        )
        
        response_body = json.loads(response['body'].read())
        if 'completion' in response_body:
            return response_body['completion']
        elif 'content' in response_body:
            return response_body['content']
        else:
            return response_body

    except Exception as e:
        st.error(f"Error analyzing logs: {str(e)}")
        return "Error analyzing logs"

def save_analysis(timestamp, logs, analysis):
    """Save analysis results to persistent storage"""
    cache_data = {}
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, 'r') as f:
            cache_data = json.load(f)
    
    cache_data[timestamp] = {
        'logs': logs,
        'analysis': analysis
    }
    
    with open(CACHE_FILE, 'w') as f:
        json.dump(cache_data, f)

def get_cached_analysis():
    """Get previously saved analyses"""
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, 'r') as f:
            return json.load(f)
    return {}

# Page config
st.set_page_config(
    page_title="EKS Log Analysis",
    page_icon="📊",
    layout="wide"
)

# Title and description
st.title("🔍 EKS Log Analysis")
st.markdown("AI-powered cross-component log analysis")

# Sidebar controls
st.sidebar.header("Analysis Settings")

# Model selection with warnings
analysis_type = st.sidebar.radio(
    "Analysis Type",
    options=list(MODEL_OPTIONS.keys()),
    help="Choose between quick results or deeper analysis"
)

if "Advanced" in analysis_type:
    st.sidebar.warning("⚠️ Advanced analysis may take several minutes to complete")
elif "Deep" in analysis_type:
    st.sidebar.info("ℹ️ Deep analysis may take a minute or two")

selected_model = MODEL_OPTIONS[analysis_type]

hours_ago = st.sidebar.slider("Hours to analyze", 1, 24, 1)
selected_log_groups = st.sidebar.multiselect(
    "Log Groups to Analyze",
    LOG_GROUPS,
    default=LOG_GROUPS
)

# Main interface
col1, col2 = st.columns([2, 1])

with col1:
    if st.button("Analyze Logs", type="primary"):
        with st.spinner("Fetching logs from multiple sources..."):
            current_time = datetime.now().isoformat()
            logs = get_logs(hours_ago, selected_log_groups)
            
            if not logs:
                st.error("No logs found for the selected period")
            else:
                st.success(f"Found {len(logs)} log entries across {len(selected_log_groups)} sources")
                
                # Show raw logs in expander grouped by source
                with st.expander("Raw Logs"):
                    for group in selected_log_groups:
                        group_logs = [log for log in logs if log.get('logGroup') == group]
                        if group_logs:
                            st.subheader(f"Logs from {group}")
                            for log in group_logs:
                                st.text(f"{datetime.fromtimestamp(log['timestamp']/1000).strftime('%Y-%m-%d %H:%M:%S')}: {log['message']}")
                
                # Get AI analysis
                with st.spinner(f"Performing {analysis_type}..."):
                    analysis = analyze_with_bedrock(logs, selected_model)
                    st.markdown("## 🤖 AI Analysis")
                    st.write(analysis)
                    
                    # Save to persistent storage
                    save_analysis(current_time, logs, analysis)

with col2:
    # Historical analyses section
    st.markdown("## 📚 Historical Analyses")
    cached_analyses = get_cached_analysis()
    if cached_analyses:
        selected_analysis = st.selectbox(
            "Previous Analyses",
            list(cached_analyses.keys()),
            format_func=lambda x: datetime.fromisoformat(x).strftime('%Y-%m-%d %H:%M:%S')
        )
        
        if st.button("Load Analysis"):
            st.write(cached_analyses[selected_analysis]['analysis'])
    
    # Statistics
    st.markdown("## 📊 Statistics")
    if 'logs' in locals():
        # Group stats by log group
        for group in selected_log_groups:
            group_logs = [log for log in logs if log.get('logGroup') == group]
            if group_logs:
                st.markdown(f"### {group.split('/')[-1]}")
                error_count = sum(1 for log in group_logs if "error" in log['message'].lower())
                warn_count = sum(1 for log in group_logs if "warning" in log['message'].lower())
                st.metric("Total Logs", len(group_logs))
                st.metric("Errors", error_count)
                st.metric("Warnings", warn_count)