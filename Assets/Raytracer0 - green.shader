
// Fra https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html
//https://msdn.microsoft.com/en-us/library/windows/desktop/bb509640(v=vs.85).aspx
//https://msdn.microsoft.com/en-us/library/windows/desktop/ff471421(v=vs.85).aspx
// rand num generator http://gamedev.stackexchange.com/questions/32681/random-number-hlsl
// http://www.reedbeta.com/blog/2013/01/12/quick-and-easy-gpu-random-numbers-in-d3d11/
// https://docs.unity3d.com/Manual/RenderDocIntegration.html
// https://docs.unity3d.com/Manual/SL-ShaderPrograms.html

Shader "Unlit/SingleColor"
{
	Properties
	{
		// inputs from gui, NB remember to also define them in "redeclaring" section
		[Toggle] _boolchooser("myBool", range(0,1)) = 0 // [Toggle] creates a checkbox in gui and give sit 0 or 1
		_floatchooser("myFloat", range(-1,1)) = 0
		_colorchooser("myColor", Color) = (1,0,0,1)
		_vec4chooser("myVec4", Vector) = (0,0,0,0)
		//_texturechooser("myTexture", 2D) = "" {} // "" er for bildefil, {} er for options
	}
		SubShader{ Pass	{
			
	CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag

		typedef vector <float, 3> vec3;  // to get more similar code to book
		typedef vector <fixed, 3> col3;

		//redeclaring ui inputs
		int _boolchooser;
		float _floatchooser;
		float4 _colorchooser; // alternative use fixed4; range of -2.0 to +2.0 and 1/256th precision. (https://docs.unity3d.com/Manual/SL-DataTypesAndPrecision.html)
		float4 _vec4chooser;
		//sampler2D _texturechooser;

	struct appdata
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
	};

	struct v2f
	{
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
	};
	
	v2f vert(appdata v)
	{
		v2f o;
		o.vertex = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;
		return o;
	}
	


////////////////////////////////////////////////////////////////////////////////////////////////////////
	fixed4 frag(v2f i) : SV_Target
	{
		float x = i.uv.x;
		float y = i.uv.y;
		col3 col = col3(0,1,0);

		return fixed4(col,1); 
	}
////////////////////////////////////////////////////////////////////////////////////


ENDCG

}}}