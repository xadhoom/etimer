[![Build Status](https://travis-ci.org/xadhoom/etimer.svg)](https://travis-ci.org/xadhoom/etimer) [![Coverage Status](https://coveralls.io/repos/github/xadhoom/etimer/badge.svg?branch=master)](https://coveralls.io/github/xadhoom/etimer?branch=master)
# Etimer

Timer module for Elixir that makes it easy to abstract time out of the tests.

Basically a rewrite of :chronos, from https://github.com/lehoff/chronos

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `etimer` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:etimer, "~> 0.1.0"}]
    end
    ```

  2. Ensure `etimer` is started before your application:

    ```elixir
    def application do
      [applications: [:etimer]]
    end
    ```


