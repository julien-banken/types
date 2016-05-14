%% -------------------------------------------------------------------
%%
%% Copyright (c) 2015-2016 Christopher Meiklejohn.  All Rights Reserved.
%% Copyright (c) 2007-2012 Basho Technologies, Inc.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% @doc Inspired by both the Lasp data type behaviour and the Riak data
%%      type behaviour.

-module(type).
-author("Christopher Meiklejohn <christopher.meiklejohn@gmail.com>").

-export([mutate/3, is_strict_inflation/2]).

%% Define some initial types.
-type type() :: gcounter | pncounter | gset | pair.
-type payload() :: term().
-type crdt() :: {type(), payload()}.
-type delta_crdt() :: {type(), {delta, payload()}}.
-type operation() :: term().
-type actor() :: term().
-type value() :: term().
-type error() :: term().

%% Initialize a CRDT.
-callback new() -> crdt().

%% Unified interface for allowing parameterized CRDTs.
-callback new([term()]) -> crdt().

%% Perform a mutation.
-callback mutate(operation(), actor(), crdt()) ->
    {ok, crdt()} | {error, error()}.

%% Perform a delta mutation.
-callback delta_mutate(operation(), actor(), crdt()) ->
    {ok, delta_crdt()} | {error, error()}.

%% Merge two replicas.
-callback merge(crdt(), crdt()) -> crdt().

%% Get the value of a CRDT.
-callback query(crdt()) -> value().

%% Compare equality.
-callback equal(crdt(), crdt()) -> boolean().

%% Inflation testing.
-callback is_inflation(crdt(), crdt()) -> boolean().
-callback is_strict_inflation(crdt(), crdt()) -> boolean().

%% Join decomposition.
-callback join_decomposition(crdt()) -> [crdt()].

%% @todo These functions are for the incremental interface.
%% -type iterator() :: term().
%% -type decomposition() :: ok | {ok, {crdt(), iterator()}}.
%% -callback join_decomposition(crdt()) -> decomposition().
%% -callback join_decomposition(iterator(), crdt()) -> decomposition().

%% @doc Generic Join composition.
-spec mutate(operation(), actor(), crdt()) ->
    {ok, crdt()} | {error, error()}.
mutate(Op, Actor, {Type, _}=CRDT) ->
    case Type:delta_mutate(Op, Actor, CRDT) of
        {ok, {Type, {delta, Delta}}} ->
            {ok, Type:merge({Type, Delta}, CRDT)};
        Error ->
            Error
    end.

%% @doc Generic check for strict inflation.
%%      We have a strict inflation if:
%%          - we have an inflation
%%          - we have different CRDTs
-spec is_strict_inflation(crdt(), crdt()) -> boolean().
is_strict_inflation({Type, _}=CRDT1, {Type, _}=CRDT2) ->
    Type:is_inflation(CRDT1, CRDT2) andalso
    not Type:equal(CRDT1, CRDT2).
