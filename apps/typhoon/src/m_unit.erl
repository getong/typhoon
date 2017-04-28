%%
%% @doc
%%   web unit test
-module(m_unit).

-compile({parse_transform, category}).

-export([return/1, fail/1, '>>='/2]).
-export([
   new/1, new/2, 
   x/1, method/1, 
   h/1, h/2, header/2, 
   d/1, payload/1, 
   r/0, request/0, request/1
]).
-export([
   check/2,
   eq/2, ne/2, le/2, lt/2, ge/2, gt/2,
   has/1
]).


-type m(A)    :: fun((_) -> [A|_]).
-type f(A, B) :: fun((A) -> m(B)).

%%
%%
-spec return(A) -> m(A).

return(_) ->
   fun(Status) ->
      [lens:get(test(), Status)|Status]
   end.

%%
%%
-spec fail(_) -> _.

fail(X) ->
   m_state:fail(X).

%%
%%
-spec '>>='(m(A), f(A, B)) -> m(B).

'>>='(X, Fun) ->
   m_state:'>>='(X, Fun).

%%
%%
new(Uri) ->
   m_http:new(Uri).

new(Uri, SOpt) ->
   m_http:new(Uri, SOpt).
   
x(Mthd) ->
   m_http:x(Mthd).

method(Mthd) ->
   m_http:method(Mthd).

h(Head) ->
   m_http:h(Head).

h(Head, Value) ->
   m_http:h(Head, Value).

header(Head, Value) ->
   m_http:header(Head, Value).

d(Value) ->
   m_http:d(Value).

payload(Value) ->
   m_http:payload(Value).

r() ->
   request().

request() ->
   request(30000).

request(Timeout) ->
   fun(State0) -> 
      [Http | State1] = ( m_http:request(Timeout) )(State0),
      [{Code, _, Head, _} | _] = Http,
      Data = scenario:decode(Http),
      State2 = [$. || 
         lens:put(code(), Code, State1),
         lens:put(head(), Head, _),
         lens:put(data(), Data, _)
      ],
      [Code | State2]
   end.

code() -> lens:c([lens:map(unit, #{}), lens:map(code,  none)]).
head() -> lens:c([lens:map(unit, #{}), lens:map(head,    [])]).
data() -> lens:c([lens:map(unit, #{}), lens:map(data,  none)]).
test() -> lens:c([lens:map(unit, #{}), lens:map(test,    [])]).

head(X) -> lens:c([lens:map(unit, #{}), lens:map(head, []), lens:pair(X, <<>>)]).

%%
%%
check(status, Expect) ->
   fun(State) ->
      Actual = lens:get(code(), State),
      Units  = lens:get(test(), State),
      Unit   = #{check => code, pass => Expect =:= Actual, expect => Expect, actual => Actual},
      [ok|lens:put(test(), [Unit|Units], State)]      
   end;

check(header, Spec) ->
   fun(State) ->
      {Header, Expect} = spec_to_header(Spec),
      Actual = lens:get(head(Header), State),
      Units  = lens:get(test(), State),
      Unit   = #{check => head, pass => Expect =:= Actual, expect => Expect, actual => Actual, header => Header},
      [ok|lens:put(test(), [Unit|Units], State)]
   end.

%%
%%
eq(Lens, Value) -> check(eq, fun(A, B) -> A =:= B end, Lens, Value).
ne(Lens, Value) -> check(ne, fun(A, B) -> A =/= B end, Lens, Value).
le(Lens, Value) -> check(le, fun(A, B) -> A =<  B end, Lens, Value).
lt(Lens, Value) -> check(lt, fun(A, B) -> A  <  B end, Lens, Value).
ge(Lens, Value) -> check(ge, fun(A, B) -> A  >= B end, Lens, Value).
gt(Lens, Value) -> check(gt, fun(A, B) -> A  >  B end, Lens, Value).

check(Check, Fun, Lens, Spec) ->
   fun(State) ->
      Expect = spec_to_value(Spec),
      Actual = scenario:lens(Lens, lens:get(data(), State)),
      Units  = lens:get(test(), State),
      Unit   = #{check => Check, pass => Fun(Actual, Expect), expect => Expect, actual => Actual, lens => Lens},
      [ok|lens:put(test(), [Unit|Units], State)]      
   end.

%%
%%
has(Lens) ->
   fun(State) ->
      Actual = scenario:lens(Lens, lens:get(data(), State)),
      Units  = lens:get(test(), State),
      Unit   = #{check => has, pass => Actual =/= [], expect => property, actual => Actual =/= [], lens => Lens},
      [ok|lens:put(test(), [Unit|Units], State)]      
   end.

%%
%%
spec_to_header(Spec) ->
   %% @todo: use htstream for header parsing
   [H, V] = binary:split(scalar:s(Spec), <<$:>>),
   Header = scalar:atom(H),
   Expect = scalar:decode(hv(V)),
   {Header, Expect}.

hv(<<$\s, X/binary>>) -> hv(X);
hv(<<$\t, X/binary>>) -> hv(X);
hv(<<$\n, X/binary>>) -> hv(X);
hv(<<$\r, X/binary>>) -> hv(X);
hv(X) -> X.

%%
%%
spec_to_value(X)
 when is_list(X) ->
   scalar:s(X);
spec_to_value(X) ->
   X.

