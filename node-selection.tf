resource "random_shuffle" "node_selection" {
  count        = var.node_name == null ? 1 : 0
  input        = var.cluster_nodes
  result_count = 1
}
