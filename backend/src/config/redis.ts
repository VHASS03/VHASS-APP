/**
 * Redis Client Proxy
 * 
 * This module now re-exports the shared Redis client to maintain
 * backward compatibility with existing code that imports from this file.
 */
import sharedRedisClient from './redis-shared';

export default sharedRedisClient;

