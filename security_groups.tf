resource "aws_security_group" "go_ethereum" {
  name        = "go-ethereum-sg-${var.network_name}"
  description = "Security group used in Ethereum network ${var.network_name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port = var.go_ethereum_p2p_port
    protocol  = "tcp"
    to_port   = var.go_ethereum_rpc_port

    cidr_blocks = [
      "0.0.0.0/0",
    ]

    description = "Allow traffic for geth p2p and rpc"
  }


  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0

    cidr_blocks = [
      "0.0.0.0/0",
    ]

    description = "Allow traffic for geth"
  }

  tags = merge(local.common_tags, tomap({ "Name" = format("ethereum-sg-%s", var.network_name) }))
}
