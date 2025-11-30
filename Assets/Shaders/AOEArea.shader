Shader "Custom/AOEArea"
{
    Properties
    {
        _FillColor("FillColor", Color) = (0,1,0,1)
        _BorderColor("Border Color", Color) = (1,1,1,1)
        _HoleColor("Hole Color", Color) = (0,0,0,0)

        _Center("Center", Vector) = (0.5,0.5, 0, 0)
        _Direction("Direction", float) = 0

        _Radius("Radius", float) = 0.4
        _Thickness("Thickness", float) = 0.1
        _Arc("Arc", int) = 360

        _BorderSize("Border Size", float) = 0.03
        _InnerBorderSize("Inner Border Size", float) = 0.03
        _FillAlpha("Fill Alpha", float) = 1
        _BorderAlpha("Border Alpha", float) = 1
        _HoleAlpha("Hole Alpha", float) = 0
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        LOD 100
        ZWrite Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            float4 _FillColor;
            float4 _BorderColor;
            float4 _HoleColor;

            float4 _Center;
            float _Direction;

            float _Radius;
            float _Thickness;
            int _Arc;

            float _BorderSize;
            float _InnerBorderSize;
            float _BorderAlpha;
            float _FillAlpha;
            float _HoleAlpha;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            float AngleDiff(float a, float b)
            {
                float d = a - b;
                d = fmod(d + 180.0, 360.0) - 180.0;
                return abs(d);
            }

            float4 frag(v2f i) : SV_Target
            {
                float2 d = (i.worldPos.xz - _Center.xz);
                float dist = length(d);

                if (dist < _Radius - _Thickness)
                {
                    float4 c = _HoleColor;
                    c.a = _HoleAlpha;
                    return c;
                }

                float inner = max(_Radius - _Thickness, 0.0);

                float ringMask = step(inner, dist) * step(dist, _Radius);

                float coneMask = 1.0;
                bool hasArc = _Arc > 0 && _Arc < 360.0;
                float angleDeg = 0;

                if (hasArc)
                {
                    float2 dir = float2(
                        cos(radians(_Direction)),
                        sin(radians(_Direction))
                    );

                    float2 nd = normalize(d);

                    float angleRad = acos(dot(nd, dir));
                    angleDeg = degrees(angleRad);

                    coneMask = step(angleDeg, _Arc * 0.5);
                }

                float mask = ringMask * coneMask;
                if (mask <= 0.0)
                    return float4(0,0,0,0);

                float outerBorderStart = _Radius - _BorderSize;
                float innerRadius = _Radius - _Thickness;
                float innerBorderEnd = innerRadius + _InnerBorderSize;

                bool inOuterBorder = dist >= outerBorderStart;
                bool inInnerBorder = innerRadius > 0 && dist <= innerBorderEnd;

                float angleT = 0.0;
                if (hasArc)
                {
                    float halfArc = _Arc * 0.5;
                    float2 nd = dist > 0.0001 ? normalize(d) : float2(1,0);
                    float angL = radians(_Direction - halfArc);
                    float angR = radians(_Direction + halfArc);
                    float2 eL = float2(cos(angL), sin(angL));
                    float2 eR = float2(cos(angR), sin(angR));

                    float perpL = abs(eL.x*nd.y - eL.y*nd.x) * dist;
                    float perpR = abs(eR.x*nd.y - eR.y*nd.x) * dist;

                    float dotL = dot(nd, eL);
                    float dotR = dot(nd, eR);
                    perpL = dotL > 0.0 ? perpL : 1e6;
                    perpR = dotR > 0.0 ? perpR : 1e6;

                    float edgeDist = min(perpL, perpR);

                    angleT = saturate((_BorderSize - edgeDist) / _BorderSize);
                }

                float outerT = saturate((dist - outerBorderStart) / _BorderSize);
                float innerT = saturate((innerBorderEnd - dist) / _InnerBorderSize);

                float t = max(max(outerT, innerT), angleT);

                float4 baseColor = _FillColor;
                baseColor.a = _FillAlpha;

                float4 borderColor = _BorderColor;
                borderColor.a = _BorderAlpha;

                return lerp(baseColor, borderColor, t);
            }

            ENDCG
        }
    }
}