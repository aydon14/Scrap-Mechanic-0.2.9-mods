#include "base_color.h"
#include "base_transform.h"
#include "base_texture.h"
#include "base_rendering.h"
#include "base_math.h"
#include "base_light.h"

struct VS_INPUT
{
	float4 vLocalPosition 	: POSITION;
	float2 vUv			 	: TEXCOORD0;
};

struct VS_OUTPUT
{
    float4 vPosition  		: SV_Position;
};

Texture2D		tGBuffer0	: register( t0 );
Texture2D		tGBuffer1	: register( t1 );
Texture2D		tGBuffer2	: register( t2 );
Texture2D		tDepth		: register( t3 );
Texture2D		tLight		: register( t4 );
Texture2D		tAo			: register( t5 );

// -------------------------------------------------------------------
// vertex functions
// -------------------------------------------------------------------

VS_OUTPUT mainVS( VS_INPUT input )
{
	VS_OUTPUT output;
	output.vPosition = float4( input.vLocalPosition.xy * 2.0 - 1.0, 1.0, 1.0 );

    return output;
};

// -------------------------------------------------------------------
// pixel functions
// -------------------------------------------------------------------

float4 mainPS( VS_OUTPUT input ) : SV_Target0
{
	float2 dims = getDims( tDepth );
	float2 uvAligned = input.vPosition.xy / dims;

	float4 vAlbedo = PointSampleCC( tGBuffer0, uvAligned ).rgba;
	float4 vSpecSaoFlagsX = PointSampleCC( tGBuffer2, uvAligned ).rgba;

	float  fDepth = PointSampleCC( tDepth, uvAligned ).r;
	float4 vLight = PointSampleCC( tLight, uvAligned ).rgba;
	float  fAo = uint( mad( vSpecSaoFlagsX.a, 255.0, 0.5 ) ) & FLAG_STATIC_AO ? vSpecSaoFlagsX.b : PointSampleCC( tAo, uvAligned ).r;

	float3 vViewSpacePosition = depthAndUvToViewPosition( fDepth, uvAligned, projectionToView );

	float3 vLightColor = lerp( vLight.rgb * ( 1.0 - fAo ), vAlbedo.rgb, vAlbedo.a );

	float fFogDistance = clamp( length( vViewSpacePosition ) - 200.0, 0.0, vCameraNearFar.y );
	float fFogFactor = clamp( 1.0 - 1.0 / exp2( fFogDistance * 0.01 ), 0.0, 1.0 );

	//return float4( (1.0 - fAo).rrr, 1.0 );
	//return float4( vAlbedoGlow.rgb, 1.0 );
	//return float4( vSpecSaoFlagsX.ggg, 1.0 );
	//return float4( vSpecSaoFlagsX.ggg * vLight.aaa, 1.0 );
	//return float4( vNormal.rgb, 1.0 );
	//return float4( vReflectDir.rgb, 1.0 );
	//return float4(vLight.rgb, 1.0);
	return float4( lerp( vLightColor, vFogColor.rgb, fFogFactor ), 1.0 );
}
