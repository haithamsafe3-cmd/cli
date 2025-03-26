package shared

import (
	"errors"
	"testing"

	"github.com/cli/cli/v2/internal/ghrepo"
	o "github.com/cli/cli/v2/pkg/option"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestQualifiedHeadRef(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		behavior           string
		ref                string
		expectedString     string
		expectedBranchName string
		expectedError      error
	}{
		{
			behavior:           "when a branch is provided, the parsed qualified head ref only has a branch",
			ref:                "feature-branch",
			expectedString:     "feature-branch",
			expectedBranchName: "feature-branch",
		},
		{
			behavior:           "when an owner and branch are provided, the parsed qualified head ref has both",
			ref:                "owner:feature-branch",
			expectedString:     "owner:feature-branch",
			expectedBranchName: "feature-branch",
		},
		{
			behavior:      "when the structure cannot be interpreted correctly, an error is returned",
			ref:           "owner:feature-branch:extra",
			expectedError: errors.New("invalid qualified head ref format 'owner:feature-branch:extra'"),
		},
	}

	for _, tc := range testCases {
		t.Run(tc.behavior, func(t *testing.T) {
			t.Parallel()

			qualifiedHeadRef, err := ParseQualifiedHeadRef(tc.ref)
			if tc.expectedError != nil {
				require.Equal(t, tc.expectedError, err)
				return
			}

			require.NoError(t, err)
			assert.Equal(t, tc.expectedString, qualifiedHeadRef.String())
			assert.Equal(t, tc.expectedBranchName, qualifiedHeadRef.BranchName())
		})
	}
}

func TestPRFindRefs(t *testing.T) {
	t.Parallel()

	t.Run("qualified head ref with owner", func(t *testing.T) {
		t.Parallel()

		refs := PRFindRefs{
			qualifiedHeadRef: mustParseQualifiedHeadRef("forkowner:feature-branch"),
		}

		require.Equal(t, "forkowner:feature-branch", refs.QualifiedHeadRef())
		require.Equal(t, "feature-branch", refs.UnqualifiedHeadRef())
	})

	t.Run("qualified head ref without owner", func(t *testing.T) {
		t.Parallel()

		refs := PRFindRefs{
			qualifiedHeadRef: mustParseQualifiedHeadRef("feature-branch"),
		}

		require.Equal(t, "feature-branch", refs.QualifiedHeadRef())
		require.Equal(t, "feature-branch", refs.UnqualifiedHeadRef())
	})

	t.Run("base repo", func(t *testing.T) {
		t.Parallel()

		refs := PRFindRefs{
			baseRepo: ghrepo.New("owner", "repo"),
		}

		require.True(t, ghrepo.IsSame(refs.BaseRepo(), ghrepo.New("owner", "repo")), "expected repos to be the same")
	})

	t.Run("matches", func(t *testing.T) {
		t.Parallel()

		testCases := []struct {
			behaviour        string
			refs             PRFindRefs
			baseBranchName   string
			qualifiedHeadRef string
			expectedMatch    bool
		}{
			{
				behaviour: "when qualified head refs don't match, returns false",
				refs: PRFindRefs{
					qualifiedHeadRef: mustParseQualifiedHeadRef("owner:feature-branch"),
				},
				baseBranchName:   "feature-branch",
				qualifiedHeadRef: "feature-branch",
				expectedMatch:    false,
			},
			{
				behaviour: "when base branches don't match, returns false",
				refs: PRFindRefs{
					qualifiedHeadRef: mustParseQualifiedHeadRef("feature-branch"),
					baseBranchName:   o.Some("not-main"),
				},
				baseBranchName:   "main",
				qualifiedHeadRef: "feature-branch",
				expectedMatch:    false,
			},
			{
				behaviour: "when head refs match and there is no base branch, returns true",
				refs: PRFindRefs{
					qualifiedHeadRef: mustParseQualifiedHeadRef("feature-branch"),
					baseBranchName:   o.None[string](),
				},
				baseBranchName:   "main",
				qualifiedHeadRef: "feature-branch",
				expectedMatch:    true,
			},
			{
				behaviour: "when head refs match and base branches match, returns true",
				refs: PRFindRefs{
					qualifiedHeadRef: mustParseQualifiedHeadRef("feature-branch"),
					baseBranchName:   o.Some("main"),
				},
				baseBranchName:   "main",
				qualifiedHeadRef: "feature-branch",
				expectedMatch:    true,
			},
		}

		for _, tc := range testCases {
			t.Run(tc.behaviour, func(t *testing.T) {
				t.Parallel()

				require.Equal(t, tc.expectedMatch, tc.refs.Matches(tc.baseBranchName, tc.qualifiedHeadRef))
			})
		}
	})
}

func mustParseQualifiedHeadRef(ref string) QualifiedHeadRef {
	parsed, err := ParseQualifiedHeadRef(ref)
	if err != nil {
		panic(err)
	}
	return parsed
}
