# TokenCache

TokenCache is a simple cache server with automatic refreshes.

It also has the following features:

  * sync/async prefetching
  * automatic retries on errors

## Usage

```elixir
Mix.install([
  {:token_cache, github: "wojtekmach/token_cache"}
])

fetch = fn ->
  {:ok, Time.utc_now(), 1000}
end

{:ok, _} = TokenCache.start_link(name: MyCache, fetch: fetch)

TokenCache.fetch(MyCache)
#=> ~T[13:40:55.707740]
TokenCache.fetch(MyCache)
#=> ~T[13:40:55.707740]

Process.sleep(1000)

TokenCache.fetch(MyCache)
#=> ~T[13:40:56.708833]
TokenCache.fetch(MyCache)
#=> ~T[13:40:56.708833]
```

## License

Copyright (c) 2022 Wojtek Mach

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
