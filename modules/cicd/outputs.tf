# -----------------------------------------------------------------------------
# CI/CDモジュール 出力定義
# -----------------------------------------------------------------------------

output "codebuild_project_name" {
  description = "CodeBuildプロジェクト名"
  value       = aws_codebuild_project.main.name
}

output "codebuild_project_arn" {
  description = "CodeBuildプロジェクトARN"
  value       = aws_codebuild_project.main.arn
}

output "codepipeline_name" {
  description = "CodePipeline名"
  value       = aws_codepipeline.main.name
}

output "codepipeline_arn" {
  description = "CodePipelineARN"
  value       = aws_codepipeline.main.arn
}
