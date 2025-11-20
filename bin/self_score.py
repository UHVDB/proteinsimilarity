#!/usr/bin/env python

import argparse
import polars as pl
import gzip

pl.Config.set_streaming_chunk_size(10_000)

def parse_args(args=None):
    description = "Calculate AAI self-alignment score for a genome."
    epilog = "Example usage: python self_score.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input",
        help="Path to PARQUET created by DIAMOND (should include self-alignments).",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output PARQUET containing AAI self-alignment score.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def calculate_self_score(input, output):
    
    # write streaming code
    self_score = (
        pl.scan_parquet(input)
            .select(['column00', 'column01', 'column11'])
            .rename({'column00':'query', 'column01':'reference', 'column11':'bitscore'})
            .filter(pl.col('query') == pl.col('reference'))
            .with_columns([
                pl.col('query').str.replace(r'_\d+$', '').cast(pl.Categorical).alias('genome')
            ])
            .group_by(pl.col('genome'))
            .agg([
                pl.len().alias('genes'),
                pl.col('bitscore').sum().alias('selfscore')
            ])
    )

    # write out parquet
    self_score.sink_parquet(output)


def main(args=None):
    args = parse_args(args)

    # calculate self score
    calculate_self_score(args.input, args.output)

if __name__ == "__main__":
    main()
