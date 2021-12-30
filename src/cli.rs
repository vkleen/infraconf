use anyhow::Result;

const BINNAME: &str = clap::crate_name!();

#[derive(Debug, clap::Parser)]
struct Cli {
    #[clap(short, long, parse(from_occurrences), global = true)]
    /// Logging verbosity, specify multiple times for ever more verbose output
    verbose: u8,

    #[clap(subcommand)]
    cmd: Cmd,
}

command_builder::build_commands!(
    Cmd {
        #[clap(setting = clap::AppSettings::Hidden)]
        /// Generate shell completions
        GenCompletions {
            #[clap(arg_enum)]
            /// The target shell
            shell: clap_generate::Shell,
        },
    },
    {
        Cmd::GenCompletions{shell} => gen_completions(shell),
    },
    test,
);

pub async fn run() -> Result<()> {
    let cli = <Cli as clap::Parser>::parse();

    init_logging(&cli);
    dispatch_cmd(cli.cmd).await
}

fn init_logging(_cli: &Cli) {
    env_logger::builder().format_timestamp(None).init();
}

fn gen_completions<G: clap_generate::Generator>(shell: G) -> Result<()> {
    Ok(clap_generate::generate(
        shell,
        &mut <Cli as clap::IntoApp>::into_app(),
        BINNAME,
        &mut std::io::stdout(),
    ))
}

mod command_builder {
    macro_rules! build_commands {
        (
            $name:ident { $($manual_fields:tt)* },
            { $($manual_dispatch:tt)* },
            $($cmd:ident),+ $(,)?
        ) => {
            $(
                mod $cmd;
            )+

            paste::paste! {
                #[derive(Debug, clap::Subcommand)]
                #[clap(about, version)]
                enum $name {
                    $($manual_fields)*
                    $(
                        #[clap(about = $cmd::ABOUT)]
                        [<$cmd:camel>]($cmd::CmdArgs),
                    )+
                }

                async fn [<dispatch_ $name:snake>](a: $name) -> anyhow::Result<()> {
                    match a {
                        $($manual_dispatch)*
                        $(
                            $name::[<$cmd:camel>](a) => $cmd::run(a).await,
                        )+
                    }
                }
            }
        }
    }
    pub(crate) use build_commands;
}
