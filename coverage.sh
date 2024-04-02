set -e # exit on error

mkdir -p coverage

# generates lcov.info
forge coverage --report lcov --ir-minimum --report-file coverage/lcov.info

# Generate html report
if [ "$CI" != "true" ]
then
    genhtml \
        --rc branch_coverage=1 \
        --keep-going \
        --output-directory coverage \
        coverage/lcov.info
fi
