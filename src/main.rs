#![feature(const_mut_refs)]

mod cli;
mod cli_builder;

use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    cli::run().await
}
