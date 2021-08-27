Shader "Custom/boidParticle"
{
    Properties
    {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        //Tags { "RenderType"="Opaque" }
		Tags{
			"Queue" = "Transparent"
			"RenderType" = "TransparentCutout"
		}

        LOD 200

        CGPROGRAM
		#include "UnityCG.cginc"
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard vertex:vert addshadow alpha:fade
        #pragma instancing_options procedural:setup

        // Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 4.0
		

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
            float3 vertex;
            float3 modelVertex;
			float3 color;
        };
        struct BoidData
		{
			float3 velocity; 
			float3 position;
			float AnimationOffset;
            float3 Color;
            float Scale;
            uint Type;
            float3 forward;
            float2 speeds;
			uint neib;
		};
      
        
		#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
		StructuredBuffer<BoidData> _BoidDataBuffer;
		#endif

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        float3 _ObjectScale;
        // float _ime;

		float4x4 eulerAnglesToRotationMatrix(float3 angles)
		{
			float ch = cos(angles.y); float sh = sin(angles.y); // heading
			float ca = cos(angles.z); float sa = sin(angles.z); // attitude
			float cb = cos(angles.x); float sb = sin(angles.x); // bank

			// Ry-Rx-Rz (Yaw Pitch Roll)
			return float4x4(
				ch * ca + sh * sb * sa, -ch * sa + sh * sb * ca, sh * cb, 0,
				cb * sa, cb * ca, -sb, 0,
				-sh * ca + ch * sb * sa, sh * sa + ch * sb * ca, ch * cb, 0,
				0, 0, 0, 1
			);
		}

		void vert(inout appdata_full v, out Input o)
		{
            UNITY_INITIALIZE_OUTPUT(Input, o);
			#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
			
            
            o.modelVertex = v.vertex;
			BoidData boidData = _BoidDataBuffer[unity_InstanceID]; 
			//BoidData boidData = _BoidDataBuffer[v.InstanceId];

			float3 pos = boidData.position.xyz; 
			float3 scl = float3(boidData.Scale, boidData.Scale, boidData.Scale);  
			
			//scl *= 0.5;
			//scl *= max(1, 5 -(float)boidData.neib/(float)10);


			float4x4 object2world = (float4x4)0; 
			object2world._11_22_33_44 = float4(scl.xyz, 1.0);

			float4x4 tmp = object2world;
			object2world._14_24_34 += pos.xyz;

			float3 worldPos = mul(object2world, v.vertex);
			float3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
			float rotY = atan2(viewDir.x, viewDir.z);
			float rotX = -asin(viewDir.y / (length(viewDir.xyz) + 1e-8)) + 90;
			float4x4 rotMatrix = eulerAnglesToRotationMatrix(float3(rotX, rotY, 0));

			object2world = mul(rotMatrix, tmp);
			object2world._14_24_34 += pos.xyz;
					   
			v.vertex = mul(object2world, v.vertex);
			v.normal = normalize(mul(object2world, v.normal));
			//o.uv_MainTex = v.uv;
			o.color = boidData.Color;
            
			#endif
            o.vertex = v.vertex;
			
		}
		
		void setup()
		{

		}

        UNITY_INSTANCING_BUFFER_START(Props)
        
		UNITY_INSTANCING_BUFFER_END(Props)
        void surf (Input IN, inout SurfaceOutputStandard o)
        {	
			#define UNITY_PROCEDURAL_INSTANCING_ENABLED true
            #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
            
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;

            //BoidData boidData = _BoidDataBuffer[unity_InstanceID]; 

            //o.Albedo = boidData.Color;
			//o.Albedo = float3(0,0,0);
			//o.Albedo = float3(IN.uv_MainTex, 0.0);
			//o.Albedo = float3(0, 0, 1);
			o.Albedo = IN.color;
			
            
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
			float alpha = max(0.0, 0.5 - length(IN.uv_MainTex - float2(0.5, 0.5)))*2;
			o.Alpha = alpha*alpha;
			o.Emission = IN.color;

            #endif
        }

        ENDCG
    }
    FallBack "Diffuse"
}
