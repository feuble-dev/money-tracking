'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { apiError } from './admin-types';

/**
 * Chargement d'une ressource d'API : données, état, erreur lisible, et
 * `reload()` après une action. Une réponse arrivée après un rechargement
 * plus récent est ignorée (pas de clignotement d'anciennes données).
 */
export function useAsync<T>(fn: () => Promise<T>, deps: unknown[] = []) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const seq = useRef(0);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const run = useCallback(fn, deps);

  const reload = useCallback(async () => {
    const id = ++seq.current;
    setLoading(true);
    setError(null);
    try {
      const result = await run();
      if (id === seq.current) setData(result);
    } catch (e) {
      if (id === seq.current) setError(apiError(e, 'Le serveur ne répond pas. Réessayez dans un instant.'));
    } finally {
      if (id === seq.current) setLoading(false);
    }
  }, [run]);

  useEffect(() => {
    reload();
  }, [reload]);

  return { data, setData, loading, error, reload };
}
