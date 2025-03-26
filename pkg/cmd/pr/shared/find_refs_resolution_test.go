package shared_test

import (
	"errors"
	"testing"

	"github.com/cli/cli/v2/pkg/cmd/pr/shared"
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

			qualifiedHeadRef, err := shared.ParseQualifiedHeadRef(tc.ref)
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
