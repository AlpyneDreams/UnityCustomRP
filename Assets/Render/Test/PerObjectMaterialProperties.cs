using UnityEngine;

[DisallowMultipleComponent]
public class PerObjectMaterialProperties : MonoBehaviour
{
	static int ID_Color		= Shader.PropertyToID("_Color");
	static int ID_Metallic	= Shader.PropertyToID("_Metallic");
	static int ID_Gloss		= Shader.PropertyToID("_Glossiness");

    static MaterialPropertyBlock block;
	
	
	public Color baseColor = Color.white;

	[Range(0.0f, 1.0f)]
	public float metallic = 0.0f, gloss = 0.5f;

    void Awake()
    {
        OnValidate();
    }

	void OnValidate()
    {
		if (block == null) {
			block = new MaterialPropertyBlock();
		}
		block.SetColor(ID_Color, baseColor);
		block.SetFloat(ID_Metallic, metallic);
		block.SetFloat(ID_Gloss, gloss);
		GetComponent<Renderer>().SetPropertyBlock(block);
	}

}
