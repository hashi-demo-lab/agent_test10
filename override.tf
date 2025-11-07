terraform {
  cloud {
    organization = "hashi-demos-apj"
    workspaces {
      name    = "sandbox_agent_test10"
      project = "sandbox"
    }
  }
}
