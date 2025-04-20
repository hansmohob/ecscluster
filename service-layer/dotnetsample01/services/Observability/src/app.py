import streamlit as st
import datetime
from log_processor import LogProcessor
from bedrock_helper import BedrockAnalyzer
from utils import format_timestamp, categorize_log_level

# Initialize processors
log_processor = LogProcessor()
bedrock_analyzer = BedrockAnalyzer()

# Page config
st.set_page_config(
    page_title="EKS Log Analysis",
    page_icon="📊",
    layout="wide"
)

# Title and description
st.title("🔍 EKS Log Analysis")
st.markdown("AI-powered analysis of your EKS cluster logs")

# Sidebar controls
st.sidebar.header("Analysis Settings")
hours_ago = st.sidebar.slider("Hours to analyze", 1, 24, 1)
log_types = st.sidebar.multiselect(
    "Log Levels",
    ["ERROR", "WARNING", "INFO", "DEBUG"],
    default=["ERROR", "WARNING"]
)

# Main content
col1, col2 = st.columns([2, 1])

with col1:
    if st.button("Analyze Logs", type="primary"):
        with st.spinner("Fetching logs..."):
            logs = log_processor.get_logs(hours_ago)
            
            if not logs:
                st.error("No logs found for the selected period")
            else:
                st.success(f"Found {len(logs)} log entries")
                
                # Show raw logs in expander
                with st.expander("Raw Logs"):
                    for log in logs:
                        level = categorize_log_level(log.get('message', ''))
                        if level in log_types:
                            st.text(f"{format_timestamp(log['timestamp'])}: {log['message']}")
                
                # Get AI analysis
                with st.spinner("Analyzing logs..."):
                    analysis = bedrock_analyzer.analyze_logs(logs)
                    st.markdown("## 🤖 AI Analysis")
                    st.write(analysis)

with col2:
    st.markdown("## 📊 Statistics")
    if 'logs' in locals():
        # Show basic stats
        total_logs = len(logs)
        error_count = sum(1 for log in logs if categorize_log_level(log.get('message', '')) == 'ERROR')
        warn_count = sum(1 for log in logs if categorize_log_level(log.get('message', '')) == 'WARNING')
        
        st.metric("Total Logs", total_logs)
        st.metric("Errors", error_count)
        st.metric("Warnings", warn_count)