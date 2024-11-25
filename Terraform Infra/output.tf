output "cluster_id" {
  value = aws_eks_cluster.Pubsub_cluster.id
}

output "node_group_id" {
  value = aws_eks_node_group.Pubsub_node_group.id
}

output "vpc_id" {
  value = aws_vpc.VPC.id
}

output "subnet_ids" {
  value = aws_subnet.Pubsub[*].id
}
