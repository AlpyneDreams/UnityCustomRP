using System.Collections;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Unity.Collections;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.Rendering.RenderGraphModule;


using RenderContext = UnityEngine.Rendering.ScriptableRenderContext;

namespace Render
{
    public static class Util
    {
        public static void ExecuteAndClear(this RenderContext context, CommandBuffer cmd)
        {
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
        }

        public static void SetShaderKeyword(this CommandBuffer cmd, string keyword, bool enabled)
        {
            if (enabled)
                cmd.EnableShaderKeyword(keyword);
            else
                cmd.DisableShaderKeyword(keyword);        
        }

        // Usage: foreach (var (index, item) in collection.Entries())
        public static IEnumerable<(int, T)> Entries<T>(this IEnumerable<T> src)
            => src.Select((item, index) => (index, item));
    }
}