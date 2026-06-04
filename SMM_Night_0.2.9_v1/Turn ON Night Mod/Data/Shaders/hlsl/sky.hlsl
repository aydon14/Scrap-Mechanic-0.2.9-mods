#include "base_transform.h"
#include "base_texture.h"
#include "base_rendering.h"

struct VS_INPUT
{
	float4 vLocalPosition 	: POSITION;
	float4 uv			 	: TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 vPosition  	: SV_POSITION;
    float2 uv 			: TEXCOORD0;
	float3 normal		: NORMAL0;
};

Texture2D tex0 : register( t0 );

VS_OUTPUT skyVS( VS_INPUT input )
{
	VS_OUTPUT output;
	output.vPosition = mul( worldToView, float4( input.vLocalPosition.xyz, 0.0 ) );
	output.vPosition = mul( viewToProjection, float4( output.vPosition.xyz, 1.0 ) );	
	output.vPosition.z = output.vPosition.w - 0.00001;
	output.uv = input.uv.xy;
	output.normal = normalize( input.vLocalPosition.xyz );
	return output;
};

float4 skyPS( VS_OUTPUT input ) : SV_TARGET0
{
	float sun = clamp( dot( vSunDirectionWorld.xyz, normalize(input.normal) ), 0.0, 1.0 );
	float4 skyColor = tex0.Sample( LinearWrapClamp, input.uv - float2( vTime.x * 0.001, 0 ) );

	return float4( skyColor.xyz + float3( 1.0, 0.75, 0.5 ) * clamp( pow( sun , 1500 ), 0.0, 1.0 ), 1.0 );
}
