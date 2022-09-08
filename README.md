## MVCC or Regular Locking

Theoretically, in `MVCC`, "reads don't block writes and writes don't block reads".  
In practice, you are likely to get one or more of - in contention situations:
- severe performance degradation
- extreme disk and memory use
- relaxed ACID guarantees

Also, it's not a problem of `MVCC` per-se but even `PostgreSQL` is not `Strict Serializable` [1, 2] from a client perspective [3, 4].

<br>

I prefer `Regular Locking`; but that's not to say it doesn't have pitfalls.  
I think it can work exceptionally well;  
&nbsp; given that you control the `size` (as in `affected rows`) and `duration` of your operations.

<br>

One of my main interests is making `client-centric` `Strict Serializable` `ACID` perform well.  
I quote Abadi [5]:
> The quality of the architecture of the system can have a significant effect on the amount of performance drop for high isolation and consistency levels.

> Poorly designed systems will push you into choosing lower isolation and consistency levels by virtue of a dramatic performance drop if you choose higher levels.

> All systems will have some performance drop, but well-designed systems will observe a much less dramatic drop.

<br>

[1] [Serializability vs “Strict” Serializability: The Dirty Secret of Database Isolation Levels](https://fauna.com/blog/serializability-vs-strict-serializability-the-dirty-secret-of-database-isolation-levels)  
[2] [Correctness Anomalies Under Serializable Isolation ](http://dbmsmusings.blogspot.com/2019/06/correctness-anomalies-under.html)  
[3] Seminal [Seeing is Believing: A Client-Centric Specification of Database
Isolation](https://www.cs.cornell.edu/lorenzo/papers/Crooks17Seeing.pdf)  
[4] [This](https://news.ycombinator.com/item?id=19221956) hackernews exchange  
[5] [An explanation of the difference between Isolation levels vs. Consistency levels ](http://dbmsmusings.blogspot.com/2019/08/an-explanation-of-difference-between.html)

## Tran structure

I'm entranced by Transaction-based concurrency control as in [env-cur-block-add](https://github.com/leosbotelho/dbo-pl/blob/main/proc/env-cur-block-add).

<br>

With a `Validation` block, at `Read Committed`; and an `Execution` block, at `Serializable`.  
Both blocks are very similar, if not identical, except for the isolation.

### Validation

Will refresh the cache and fail fast on error conditions.

### Execution

If you garantee the locks are kept until tran end; and you enforce an access order; then you eliminate deadlocks between writes.

<br>

Deadlocks could still be possible between reads and writes, though.

<br>

Then you can just retry.  
Or minimize it; somewhat proportional to your control over - the code of the - reads and writes.

## Batch processing

[token-mov-btr](https://github.com/leosbotelho/dbo-pl/blob/main/proc/token-mov-btr) moves data from an etl, `out of distribution` db to the prod db.

Something very important to observe is the use of `keyset pagination`, re:  
&nbsp; https://vladmihalcea.com/sql-seek-keyset-pagination/  
&nbsp; https://use-the-index-luke.com/no-offset

Also notice the isolation is `Read Uncommitted`.  
I'm doing somewhat manual concurrency control;  
&nbsp; decisions cascades from `Prov`.

<br>

What I alluded to in [set-suki](https://github.com/leosbotelho/set-suki#addendum), can be peeked at [new-token-or-prov-sel-btr](https://github.com/leosbotelho/dbo-pl/blob/main/proc/token/new-token-or-prov-sel-btr).

<br>

And my use of `Memory` and '`Ramdisk`' tables for `batch` proc params in almost any `btr`.

## view

Say you `select`:
```
select Hash, Addr from Token_V
```
<br>

So you only need `Token`, `TokenAddr`, `Addr`.  
But the view will also pull  
&nbsp; `Prov`, `TokenProv`, `Ref_Chain`, `Var_Token` and `Var_Token_O`.

<br>

That's because there's no optimization that removes unused tables from views.

<br>

So you actually have to split chunky views.

## bp

Especially err localization for procs.

## hash

Sophisticated systems with - parenthesized - `BTrees` and `hashes` as basis;  
&nbsp; I love it.

<br>

Unfortunately, the innodb `hash` index type doesn't support `foreign keys`, and as such is unusable - for most purposes.

<br>

Nevertheless, `hashes` with `BTree` indexes can also make sense.
