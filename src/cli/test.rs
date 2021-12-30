use log::debug;

#[derive(Debug, clap::Args)]
pub struct CmdArgs {}

pub const ABOUT: &str = "Test subcommand";

pub async fn run(_: CmdArgs) -> anyhow::Result<()> {
    debug!("It works!");
    anyhow::Ok(())
}
