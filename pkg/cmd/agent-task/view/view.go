package view

import (
	"net/http"

	"github.com/MakeNowJust/heredoc"
	"github.com/cli/cli/v2/pkg/cmdutil"
	"github.com/cli/cli/v2/pkg/iostreams"
	"github.com/spf13/cobra"
)

type ViewOptions struct {
	HttpClient func() (*http.Client, error)
	IO         *iostreams.IOStreams

	SelectorArg string
}

func NewCmdView(f *cmdutil.Factory, runF func(*ViewOptions) error) *cobra.Command {
	opts := &ViewOptions{
		IO:         f.IOStreams,
		HttpClient: f.HttpClient,
	}

	cmd := &cobra.Command{
		Use:   "view <session-id>",
		Short: "View an agent task session",
		Long: heredoc.Doc(`
			View an agent task session.
		`),
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			opts.SelectorArg = args[0]

			if runF != nil {
				return runF(opts)
			}
			return viewRun(opts)
		},
	}

	return cmd
}

func viewRun(opts *ViewOptions) error {
	return nil
}
