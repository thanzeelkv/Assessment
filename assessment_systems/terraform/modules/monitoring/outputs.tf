output "log_analytics_workspace_id"   { value = azurerm_log_analytics_workspace.main.id }
output "log_analytics_workspace_name" { value = azurerm_log_analytics_workspace.main.name }
output "monitor_workspace_id"         { value = azurerm_monitor_workspace.main.id }
output "grafana_endpoint"             { value = azurerm_dashboard_grafana.main.endpoint }
